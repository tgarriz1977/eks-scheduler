output "lambda_function_name" {
  description = "Nombre de la funcion Lambda"
  value       = aws_lambda_function.eks_scheduler.function_name
}

output "lambda_function_arn" {
  description = "ARN de la funcion Lambda"
  value       = aws_lambda_function.eks_scheduler.arn
}

output "schedule_stop_arn" {
  description = "ARN del schedule de apagado"
  value       = aws_scheduler_schedule.stop.arn
}

output "schedule_start_arn" {
  description = "ARN del schedule de encendido"
  value       = aws_scheduler_schedule.start.arn
}

output "sns_topic_arn" {
  description = "ARN del topic SNS para notificaciones"
  value       = var.notification_email != "" ? aws_sns_topic.eks_scheduler[0].arn : null
}
