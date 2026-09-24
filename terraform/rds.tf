# DB マスターパスワードは Terraform で生成し、平文はコード/ステートのみに存在。
# 値は SSM Parameter Store (SecureString) に保存し、ECS から参照する。
resource "random_password" "db" {
  length  = 24
  special = false # RDS が一部記号を嫌うため英数字に限定
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-db-subnet"
  subnet_ids = aws_subnet.private[*].id
  tags       = { Name = "${local.name}-db-subnet" }
}

resource "aws_db_instance" "main" {
  identifier     = "${local.name}-db"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  multi_az               = false # 最小構成: Single-AZ
  publicly_accessible    = false

  # 学習用途: 削除を容易にする設定。本番では deletion_protection=true / skip_final_snapshot=false。
  skip_final_snapshot = true
  deletion_protection = false
  apply_immediately   = true

  tags = { Name = "${local.name}-db" }
}

# ---- シークレットを SSM Parameter Store に保存 ----
resource "aws_ssm_parameter" "db_password" {
  name  = "/${local.name}/db/password"
  type  = "SecureString"
  value = random_password.db.result
  tags  = { Name = "${local.name}-db-password" }
}

# アプリが使う DATABASE_URL（DSN）を組み立てて保存。
resource "aws_ssm_parameter" "database_url" {
  name = "/${local.name}/database_url"
  type = "SecureString"
  value = format(
    "host=%s port=5432 user=%s password=%s dbname=%s sslmode=require",
    aws_db_instance.main.address,
    var.db_username,
    random_password.db.result,
    var.db_name,
  )
  tags = { Name = "${local.name}-database-url" }
}

# JWT の署名鍵も生成して SSM に保存（アプリの JWT_SECRET）。
resource "random_password" "jwt_secret" {
  length  = 48
  special = false
}

resource "aws_ssm_parameter" "jwt_secret" {
  name  = "/${local.name}/jwt_secret"
  type  = "SecureString"
  value = random_password.jwt_secret.result
  tags  = { Name = "${local.name}-jwt-secret" }
}
