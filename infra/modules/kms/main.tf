data "aws_caller_identity" "current" {}

resource "aws_kms_key" "main" {
  description             = "Order Management CMK — ${var.env}"
  enable_key_rotation     = true
  deletion_window_in_days = var.deletion_window_in_days
  tags                    = var.tags
}

resource "aws_kms_alias" "main" {
  name          = "alias/orders-${var.env}"
  target_key_id = aws_kms_key.main.key_id
}
