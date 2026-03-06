# -------------------------------------------------------
# SNS Topic + Email Subscription para notificaciones
# Solo se crea si notification_email tiene valor
# -------------------------------------------------------
resource "aws_sns_topic" "eks_scheduler" {
  count = var.notification_email != "" ? 1 : 0
  name  = "eks-scheduler-notifications"
  tags  = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.eks_scheduler[0].arn
  protocol  = "email"
  endpoint  = var.notification_email
}
