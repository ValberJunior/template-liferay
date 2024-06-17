data "aws_vpc" "selected" {
  id = local.config.vpc_id
}

data "aws_subnet" "selected" {
  id = local.config.subnet_id
}

resource "aws_security_group" "rds_sg" {
  name        = "${local.config.rds_instance_name}-sg"
  description = "Security Group for RDS instance"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.config.rds_instance_name}-sg"
  }
}

resource "aws_db_instance" "template-rds" {
  allocated_storage          = local.config.rds_volume_size
  max_allocated_storage      = local.config.rds_volume_size
  engine                     = "mysql"
  engine_version             = "8.0"
  instance_class             = local.config.rds_instance_type
  db_name                    = local.config.database_name
  username                   = local.config.db_username
  password                   = local.config.db_password
  identifier                 = local.config.rds_instance_name
  publicly_accessible        = true
  skip_final_snapshot        = true
  vpc_security_group_ids     = [aws_security_group.rds_sg.id]
 
  tags = {
    Name = "${local.config.rds_instance_name}"
  }

}

output "rds" {
  value = aws_db_instance.template-rds.endpoint
}
