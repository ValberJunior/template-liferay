
resource "aws_efs_file_system" "efs-liferay" {
  creation_token = "liferay-efs"
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  tags = {
    Template = "Liferay"
    Name = "liferay-efs"
  }
}

resource "aws_efs_backup_policy" "policy" {
  file_system_id = aws_efs_file_system.efs-liferay.id

  backup_policy {
    status = "ENABLED"
  }
}

resource "aws_efs_access_point" "access-point" {
  file_system_id = aws_efs_file_system.efs-liferay.id

  root_directory {
    path = "/liferay"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }
}

resource "aws_efs_mount_target" "mount" {
  file_system_id = aws_efs_file_system.efs-liferay.id
  subnet_id      = local.config.subnet_id
  security_groups = [aws_security_group.web_efs_security_group.id]
}

output "efs_dns_name" {
  value = aws_efs_file_system.efs-liferay.dns_name
}
