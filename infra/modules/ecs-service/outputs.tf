output "service_name" { value = aws_ecs_service.main.name }
output "task_def_arn" { value = aws_ecs_task_definition.main.arn }
output "ecs_sg_id" { value = aws_security_group.ecs.id }
output "task_role_arn" { value = aws_iam_role.task.arn }
