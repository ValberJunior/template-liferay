### REDE

data "aws_vpc" "selected" {
  id = local.config.vpc_id
}

data "aws_subnet" "selected" {
  id = local.config.subnet_id
}

resource "aws_security_group" "web_efs_security_group" {
  name        = "access_cluster_${local.config.cluster_name}_sg"
  description = "Allow SSH and HTTP"
  vpc_id      = data.aws_vpc.selected.id
 
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
 # ingress {
 #   description = "Cluster Access"
 #   from_port   = 6550
 #   to_port     = 6550
 #   protocol    = "tcp"
 #   cidr_blocks = ["0.0.0.0/0"]
 # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Template = "Liferay"
  }
}


resource "aws_eip" "webip" {
  tags = {
    Template = "Liferay"
    Name = "${local.config.cluster_name}-eip"
  }
}

output "instance_ip_addr" {
  value = aws_eip.webip.public_ip
}
