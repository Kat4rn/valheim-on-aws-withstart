resource "aws_sns_topic" "valheim" {
  name = "valheim_server_status"
  tags = merge(local.tags,
    {}
  )
}

resource "aws_sns_topic_subscription" "valheim" {
  topic_arn = aws_sns_topic.valheim.arn
  protocol  = "email"
  endpoint  = "cschwarzwahlfeld@gmail.com"
}

resource "aws_cloudwatch_metric_alarm" "stop_valheim" {
  alarm_name          = "stop_valheim_server"
  alarm_description   = "Will stop the Valheim server after a period of inactivity"
  comparison_operator = "LessThanThreshold"
  datapoints_to_alarm = "1"
  evaluation_periods  = "1"
  metric_name         = "NetworkIn"
  period              = "900"
  statistic           = "Average"
  namespace           = "AWS/EC2"
  threshold           = "50000"
  alarm_actions = [
    aws_sns_topic.valheim.arn,
    "arn:aws:swf:ap-southeast-2:063286155141:action/actions/AWS_EC2.InstanceId.Stop/1.0",
  ]
  dimensions = {
    "InstanceId" = aws_instance.valheim.id
  }
  tags = merge(local.tags,
    {}
  )
}

resource "aws_cloudwatch_event_rule" "valheim_starting" {
  name        = "valheim-starting"
  description = "Used to trigger notifications when the Valheim server starts"
  event_pattern = jsonencode({
    source : [
      "aws.ec2"
    ],
    "detail-type" : [
      "EC2 Instance State-change Notification"
    ],
    detail : {
      state : [
        "pending"
      ],
      "instance-id" : [
        aws_instance.valheim.id
      ]
    }
  })
  tags = merge(local.tags,
    {}
  )
}

resource "aws_cloudwatch_event_target" "valheim_starting" {
  rule      = aws_cloudwatch_event_rule.valheim_starting.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.valheim.arn
  input_transformer {
    input_paths = {
      "account"     = "$.account"
      "instance-id" = "$.detail.instance-id"
      "region"      = "$.region"
      "state"       = "$.detail.state"
      "time"        = "$.time"
    }
    input_template = "\"At <time>, the status of your EC2 instance <instance-id> on account <account> in the AWS Region <region> has changed to <state>.\""
  }
}

data "aws_route53_zone" "selected" {
  count = var.domain != "" ? 1 : 0
  name  = "cwahlfeld.com."
}

output "monitoring_url" {
  value = format("%s%s%s", "http://", var.domain != "" ? format("%s%s", "valheim.", var.domain) : aws_instance.valheim.public_dns, ":19999")
}
