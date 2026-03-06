# -------------------------------------------------------
# IAM Role para Lambda
# -------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "eks-scheduler-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

# Permisos para EKS (listar y actualizar node groups)
data "aws_iam_policy_document" "lambda_eks" {
  statement {
    actions = [
      "eks:ListNodegroups",
      "eks:UpdateNodegroupConfig",
      "eks:DescribeNodegroup",
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.notification_email != "" ? [1] : []
    content {
      actions   = ["sns:Publish"]
      resources = [aws_sns_topic.eks_scheduler[0].arn]
    }
  }
}

resource "aws_iam_policy" "lambda_eks" {
  name   = "eks-scheduler-lambda-eks-policy"
  policy = data.aws_iam_policy_document.lambda_eks.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_eks" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_eks.arn
}

# CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# -------------------------------------------------------
# Lambda Function
# -------------------------------------------------------
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/../lambda/index.py"
  output_path = "${path.module}/../lambda/package.zip"
}

resource "aws_lambda_function" "eks_scheduler" {
  function_name    = "eks-scheduler"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 128
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = var.notification_email != "" ? aws_sns_topic.eks_scheduler[0].arn : ""
    }
  }

  tags = var.tags
}
