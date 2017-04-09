# Lambda function that logs to CloudWatch

variable "name" {}
variable "s3_bucket" {}
variable "s3_key" {}

variable "handler" { default = "main.handler" }
variable "runtime" { default = "python2.7" }
variable "memory_size" { default = 128 }
variable "timeout" { default = 3 }
variable "log_retention_in_days" { default = 0 }
variable "env_vars" { type = "map" default = {} }

# the lambda function itself
resource "aws_lambda_function" "lambda" {
  function_name = "${var.name}"
  handler = "${var.handler}"
  s3_bucket = "${data.aws_s3_bucket_object.lambda_file.bucket}"
  s3_key = "${data.aws_s3_bucket_object.lambda_file.key}"
  s3_object_version = "${data.aws_s3_bucket_object.lambda_file.version_id}"
  runtime = "${var.runtime}"
  timeout = "${var.timeout}"
  memory_size = "${var.memory_size}"
  role = "${aws_iam_role.lambda.arn}"
  # add AWS_ACCOUNT to the environment variables if it's not there
  environment {
    variables = "${merge(map("AWS_ACCOUNT", "${data.aws_caller_identity.current.account_id}"), "${var.env_vars}")}"
  }
  # create the lg first, then the lambda
  # remove the lambda first then the lg
  depends_on = ["aws_cloudwatch_log_group.lambda"]
}

# logs
resource "aws_cloudwatch_log_group" "lambda" {
  name = "/aws/lambda/${var.name}"
  retention_in_days = "${var.log_retention_in_days}"
}

# role for the lambda
resource "aws_iam_role" "lambda" {
  name = "${var.name}"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
}
EOF
}

# allow the lambda to log
resource "aws_iam_role_policy" "allow_logging" {
  name = "allow_logging"
  role = "${aws_iam_role.lambda.id}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "logs:DescribeLogGroups"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name}"
      },
      {
        "Action": [
          "logs:DescribeLogStreams",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name}:log-stream:*"
      }
    ]
}
EOF
}

# s3 object version
data "aws_s3_bucket_object" "lambda_file" {
  bucket = "${var.s3_bucket}"
  key = "${var.s3_key}"
}

# current region
data "aws_region" "current" { current = true }

# account id
data "aws_caller_identity" "current" {}

output "function_arn" { value = "${aws_lambda_function.lambda.arn}" }
output "function_name" { value = "${aws_lambda_function.lambda.function_name}" }
output "log_group_arn" { value = "${aws_cloudwatch_log_group.lambda.arn}" }
output "role_id" { value = "${aws_iam_role.lambda.id}" }
output "role_arn" { value = "${aws_iam_role.lambda.arn}" }

