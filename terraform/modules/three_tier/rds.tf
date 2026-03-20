resource "aws_db_subnet_group" "db" {
  name       = "${local.name}-db-subnet-group"
  subnet_ids = aws_subnet.db[*].id

  tags = local.tags
}

resource "aws_db_parameter_group" "mysql" {
  name        = "${local.name}-mysql-pg"
  family      = "mysql8.0"
  description = "MySQL parameter group"

  tags = local.tags
}

resource "aws_db_instance" "primary" {
  identifier = "${local.name}-primary"

  engine         = "mysql"
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class

  allocated_storage     = var.rds_allocated_storage
  storage_encrypted     = true
  multi_az              = var.rds_multi_az
  publicly_accessible   = false
  storage_type          = "gp3"

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  db_name  = var.rds_db_name
  username = random_string.db_username.result
  password = random_password.db_password.result

  backup_retention_period = var.rds_backup_retention_days
  delete_automated_backups = true
  final_snapshot_identifier = "${local.name}-final"

  parameter_group_name = aws_db_parameter_group.mysql.name

  skip_final_snapshot = var.environment != "prod"

  apply_immediately = false
  auto_minor_version_upgrade = true

  tags = local.tags
}

resource "aws_db_instance" "read_replica" {
  count = var.rds_create_read_replica ? 1 : 0

  identifier = "${local.name}-read-replica"

  engine         = "mysql"
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class

  allocated_storage   = var.rds_allocated_storage
  storage_encrypted   = true
  publicly_accessible = false
  storage_type        = "gp3"

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  replicate_source_db = aws_db_instance.primary.id

  backup_retention_period = var.rds_backup_retention_days

  parameter_group_name = aws_db_parameter_group.mysql.name

  skip_final_snapshot = var.environment != "prod"

  tags = local.tags
}

