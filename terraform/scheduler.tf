# -------------------------------------------------------
# IAM Role para EventBridge Scheduler
# -------------------------------------------------------
data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "eks-scheduler-eventbridge-role"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "scheduler_invoke_lambda" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.eks_scheduler.arn]
  }
}

resource "aws_iam_policy" "scheduler_invoke_lambda" {
  name   = "eks-scheduler-invoke-lambda-policy"
  policy = data.aws_iam_policy_document.scheduler_invoke_lambda.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "scheduler_invoke_lambda" {
  role       = aws_iam_role.scheduler.name
  policy_arn = aws_iam_policy.scheduler_invoke_lambda.arn
}

# -------------------------------------------------------
# EventBridge Scheduler - STOP (22:00 ART)
# -------------------------------------------------------
resource "aws_scheduler_schedule" "stop" {
  name        = "eks-scheduler-stop"
  description = "Apaga los nodos del cluster EKS a las 22:00 ART"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.schedule_stop
  schedule_expression_timezone = var.schedule_timezone

  target {
    arn      = aws_lambda_function.eks_scheduler.arn
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      cluster_name = var.cluster_name
      action       = "stop"
    })
  }
}

# -------------------------------------------------------
# EventBridge Scheduler - START (07:00 ART)
# -------------------------------------------------------
resource "aws_scheduler_schedule" "start" {
  name        = "eks-scheduler-start"
  description = "Enciende los nodos del cluster EKS a las 07:00 ART"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.schedule_start
  schedule_expression_timezone = var.schedule_timezone

  target {
    arn      = aws_lambda_function.eks_scheduler.arn
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      cluster_name     = var.cluster_name
      action           = "start"
      node_groups      = var.node_groups_config
    })
  }
}
