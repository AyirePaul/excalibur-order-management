output "schedule_arn" { value = aws_scheduler_schedule.daily_report.arn }
output "task_definition_arn" { value = aws_ecs_task_definition.runner.arn }
