output "user_pool_id" { value = aws_cognito_user_pool.main.id }
output "app_client_id" { value = aws_cognito_user_pool_client.main.id }
output "hosted_ui_domain" { value = aws_cognito_user_pool_domain.main.domain }
output "authority" { value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.main.id}" }

data "aws_region" "current" {}
