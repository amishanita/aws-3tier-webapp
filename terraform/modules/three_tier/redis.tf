resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.name}-redis-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  tags       = local.tags
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${local.name}-redis"
  replication_group_description = "Redis for ${local.name}"

  engine         = "redis"
  node_type      = var.redis_node_type
  port           = var.redis_port
  subnet_group_name = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]

  num_cache_clusters   = 1
  automatic_failover_enabled = var.redis_automatic_failover_enabled

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  auth_token = random_password.redis_password.result

  tags = local.tags
}

