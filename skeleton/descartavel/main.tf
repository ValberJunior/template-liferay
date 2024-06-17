data "aws_vpc" "selected" {
  id = local.config.vpc_id
}

data "aws_subnet" "selected" {
  id = local.config.subnet_id
}

data "aws_ami" "amazon-linux" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_security_group" "web_security_group" {
  name = "access_cluster_${local.config.cluster_name}_sg"
}

resource "aws_instance" "liferay-vm" {
  ami             = data.aws_ami.amazon-linux.id
  key_name        = local.config.keypar
  security_groups = [data.aws_security_group.web_efs_security_group.id]
  instance_type   = local.config.instance_type
  subnet_id       = data.aws_subnet.selected.id
  user_data = <<EOF
#!/bin/bash
# DEPENDENCIES
sudo yum update && sudo yum upgrade
sudo yum install -y curl-minimal wget git unzip docker sed nano openssl sed
sudo service docker start && sudo systemctl enable docker.service
sudo usermod -a -G docker ec2-user && newgrp docker
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/libexec/docker/cli-plugins/docker-compose 
sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose
sudo yum install -y amazon-efs-utils
sudo yum install nfs-utils -y
wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.27.7/2023-11-02/bin/linux/amd64/kubectl
chmod +x ./kubectl && mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH
sudo usermod -aG docker ec2-user
sudo docker login ${var.registry_host} -u ${var.registry_user} -p ${var.registry_password}
sudo mkdir -p /home/ec2-user/.docker
sudo cp /root/.docker/config.json /home/ec2-user/.docker/config.json
sudo chown -R ec2-user:ec2-user /home/ec2-user/.docker


# MOUNT EFS
sudo mkdir /mnt/efs
sudo mkdir /mnt/kibana
sudo mkdir /mnt/elastic

sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev ${data.aws_efs_file_system.efs-liferay.dns_name}:/ /mnt/efs 
echo "${data.aws_efs_file_system.efs-liferay.dns_name}:/ /mnt/efs nfs4 defaults,_netdev 0 0" | sudo tee -a /etc/fstab

sudo chown 1000:1000 /mnt
sudo chown 1000:1000 /mnt/efs 
sudo chown 1000:1000 /mnt/kibana 
sudo chown 1000:1000 /mnt/elastic


# K8S CONFIGURATION
echo "
mirrors:
  ${var.registry_host}:
    endpoint:
      - http://${var.registry_host}
configs:
  ${var.registry_host}:
    auth:
      username: ${var.registry_user}
      password: ${var.registry_password}
" > registries.yaml

k3d cluster create k3s \
    --servers 1 \
    -p "80:80@loadbalancer" \
    -p "443:443@loadbalancer" \
    --api-port 6550 \
    --k3s-arg "--disable=traefik@server:*" \
    --kubeconfig-update-default \
    --volume /mnt:/mnt@server:0 \
    --registry-config "./registries.yaml"


helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add metallb https://metallb.github.io/metallb
helm repo add cert-manager https://charts.jetstack.io
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx
helm install metallb metallb/metallb --create-namespace -n metallb-system
helm install cert-manager cert-manager/cert-manager --create-namespace --namespace cert-manager --version v1.14.4
kubectl apply -f "https://github.com/jetstack/cert-manager/releases/download/v1.14.4/cert-manager.crds.yaml"
kubectl create namespace lfr-stack

echo "
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: teste@vertigo.com.br
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
" | kubectl apply -f -

export TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
export EC2_PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
echo "IP_EC2 = $EC2_PUBLIC_IP"

echo "
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
    - $EC2_PUBLIC_IP/32
" | kubectl apply -f -

mkdir /home/ec2-user/.kube && k3d kubeconfig get k3s > /home/ec2-user/.kube/config

EOF

  root_block_device {
    volume_size = local.config.volume_size
  }

  tags = {
    Name = local.config.cluster_name
  }
}

data "aws_eip" "webip" {
  filter {
    name   = "tag:Name"
    values = ["liferay-eip"]
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.liferay-vm.id
  allocation_id = data.aws_eip.webip.id
}

