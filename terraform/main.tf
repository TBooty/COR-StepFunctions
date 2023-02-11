terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = var.region
  default_tags {
   tags = {
     Environment = "Test"
     Project     = "CORStepFunctions"
   }
 }
}

#Setup source code for lambda to use
provider "archive" {}
data "archive_file" "handler1Zip" {
  type        = "zip"
  source_file = "../functions/handler1/lambda.py"
  output_path = "handler1.zip"
}
data "archive_file" "handler2Zip" {
  type        = "zip"
  source_file = "../functions/handler2/lambda.py"
  output_path = "handler2.zip"
}
data "archive_file" "handler3Zip" {
  type        = "zip"
  source_file = "../functions/handler3/lambda.py"
  output_path = "handler3.zip"
}
data "archive_file" "handler4Zip" {
  type        = "zip"
  source_file = "../functions/handler4/lambda.py"
  output_path = "handler4.zip"
}


#Allow lambda to assume role
data "aws_iam_policy_document" "policy" {
  statement {
    sid    = "LambdaPolicy"
    effect = "Allow"
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

#Lambda role to use for the service
resource "aws_iam_role" "stepFuncRole" {
  name               = "lambda_role"
  assume_role_policy = data.aws_iam_policy_document.policy.json
}

# Create IAM role for AWS Step Function
resource "aws_iam_role" "iam_for_sfn" {
  name = "StepFunctionExecRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "states.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "policy_invoke_lambda" {
  name        = "stepFunctionSampleLambdaFunctionInvocationPolicy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "InvokeLambda",
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction",
                "lambda:InvokeAsync"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}


// Attach policy to IAM Role for Step Function
resource "aws_iam_role_policy_attachment" "iam_for_sfn_attach_policy_invoke_lambda" {
  role       = aws_iam_role.iam_for_sfn.name
  policy_arn = aws_iam_policy.policy_invoke_lambda.arn
}

resource "aws_lambda_function" "Dispense1" {
  function_name = "${var.lambda_name}_4"
  filename         = data.archive_file.handler4Zip.output_path
  source_code_hash = data.archive_file.handler4Zip.output_base64sha256
  role    = aws_iam_role.stepFuncRole.arn
  handler = "lambda.lambda_handler"
  runtime = "python3.9"
  timeout = 300
}

resource "aws_lambda_function" "Dispense10" {
  function_name = "${var.lambda_name}_3"
  filename         = data.archive_file.handler3Zip.output_path
  source_code_hash = data.archive_file.handler3Zip.output_base64sha256
  role    = aws_iam_role.stepFuncRole.arn
  handler = "lambda.lambda_handler"
  runtime = "python3.9"
  timeout = 300
}

resource "aws_lambda_function" "Dispense20" {
  function_name = "${var.lambda_name}_2"
  filename         = data.archive_file.handler2Zip.output_path
  source_code_hash = data.archive_file.handler2Zip.output_base64sha256
  role    = aws_iam_role.stepFuncRole.arn
  handler = "lambda.lambda_handler"
  runtime = "python3.9"
  timeout = 300
}

resource "aws_lambda_function" "Dispense50" {
  function_name = "${var.lambda_name}_1"
  filename         = data.archive_file.handler1Zip.output_path
  source_code_hash = data.archive_file.handler1Zip.output_base64sha256
  role    = aws_iam_role.stepFuncRole.arn
  handler = "lambda.lambda_handler"
  runtime = "python3.9"
  timeout = 300
}

resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = "step_function_dispenser"
  role_arn = aws_iam_role.iam_for_sfn.arn

  definition = <<EOF
{
  "Comment": "A state machine that mocks an ATM dispenser.",
  "StartAt": "Dispense50",
  "States": {
    "Dispense50": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.Dispense50.arn}",
      "Retry": [
        {
          "ErrorEquals": [
            "States.TaskFailedId"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "Next": "Dispense20"
    },
    "Dispense20": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.Dispense20.arn}",
      "Retry": [
        {
          "ErrorEquals": [
            "States.TaskFailedId"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "Next": "Dispense10"
    },
    "Dispense10": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.Dispense10.arn}",
      "Retry": [
        {
          "ErrorEquals": [
            "States.TaskFailedId"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "Next": "Dispense1"
    },
    "Dispense1": {
      "Type": "Task",
      "End": true,
      "Resource": "${aws_lambda_function.Dispense1.arn}",
      "Retry": [
        {
          "ErrorEquals": [
            "States.TaskFailedId"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ]
    }
  }
}
EOF

  depends_on = [aws_lambda_function.Dispense50,aws_lambda_function.Dispense20, aws_lambda_function.Dispense10, aws_lambda_function.Dispense1]
}