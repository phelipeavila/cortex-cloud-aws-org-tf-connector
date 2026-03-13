#---------------------------------------
# CloudTrail SQS + SNS Integration
#---------------------------------------

resource "aws_sqs_queue" "cloudtrail_logs" {
  count = local.cloudtrail_enabled ? 1 : 0
  name  = local.sqs_queue_name
  tags  = local.tags
}

resource "aws_sqs_queue_policy" "cloudtrail_logs" {
  count     = local.cloudtrail_enabled ? 1 : 0
  queue_url = aws_sqs_queue.cloudtrail_logs[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "sns.amazonaws.com" }
        Action    = "SQS:SendMessage"
        Resource  = aws_sqs_queue.cloudtrail_logs[0].arn
        Condition = {
          ArnEquals = { "aws:SourceArn" = var.cloudtrail_sns_arn }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "cloudtrail_to_sqs" {
  count     = local.cloudtrail_enabled ? 1 : 0
  topic_arn = var.cloudtrail_sns_arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.cloudtrail_logs[0].arn
}
