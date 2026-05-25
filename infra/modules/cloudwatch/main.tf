# ====================================
# ログロググループ
# ====================================

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/logapp-backend"
  retention_in_days = 30

  tags = { Name = "logapp-backend-logs" }
}

# ====================================
# エラーログのメトリクスフィルター
# ====================================

resource "aws_cloudwatch_log_metric_filter" "error_logs" {
  name           = "logapp-error-logs"
  log_group_name = aws_cloudwatch_log_group.backend.name
  pattern        = "{ $.levelname = \"ERROR\" }"

  metric_transformation {
    name          = "ErrorCount"
    namespace     = "LogApp/Errors"
    value         = "1"
    default_value = "0"
  }
}

# ====================================
# SNSトピック（通知の中継役）
# ====================================

resource "aws_sns_topic" "alerts" {
  name = "logapp-alerts"
  tags = { Name = "logapp-alerts" }
}

# ====================================
# SNS → Slack通知（Lambda経由）
# ====================================

resource "aws_iam_role" "lambda_sns" {
  name = "logapp-lambda-sns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_sns.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda関数のコード
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda.zip"

  source {
    content  = <<EOF
import json
import urllib.request
import os

def handler(event, context):
    webhook_url = os.environ['SLACK_WEBHOOK_URL']
    
    for record in event['Records']:
        sns_message = json.loads(record['Sns']['Message'])
        
        alarm_name = sns_message.get('AlarmName', 'Unknown')
        new_state = sns_message.get('NewStateValue', 'Unknown')
        reason = sns_message.get('NewStateReason', 'Unknown')
        
        if new_state == 'ALARM':
            emoji = '🚨'
            color = 'danger'
        else:
            emoji = '✅'
            color = 'good'
        
        message = {
            "attachments": [
                {
                    "color": color,
                    "title": f"{emoji} CloudWatchアラート",
                    "fields": [
                        {
                            "title": "アラート名",
                            "value": alarm_name,
                            "short": True
                        },
                        {
                            "title": "ステータス",
                            "value": new_state,
                            "short": True
                        },
                        {
                            "title": "理由",
                            "value": reason,
                            "short": False
                        }
                    ]
                }
            ]
        }
        
        data = json.dumps(message).encode('utf-8')
        req = urllib.request.Request(
            webhook_url,
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        urllib.request.urlopen(req)
    
    return {'statusCode': 200}
EOF
    filename = "index.py"
  }
}

resource "aws_lambda_function" "slack_notification" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "logapp-slack-notification"
  role             = aws_iam_role.lambda_sns.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }

  tags = { Name = "logapp-slack-notification" }
}

resource "aws_lambda_permission" "sns" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notification.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notification.arn
}

# ====================================
# CPU使用率アラート
# ====================================

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "logapp-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "ECSのCPU使用率が5%以上になりました"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  tags = { Name = "logapp-cpu-high" }
}

# ====================================
# エラーログアラート
# ====================================

resource "aws_cloudwatch_metric_alarm" "error_logs" {
  alarm_name          = "logapp-error-logs"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ErrorCount"
  namespace           = "LogApp/Errors"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "エラーログが発生しました"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = { Name = "logapp-error-logs" }
}