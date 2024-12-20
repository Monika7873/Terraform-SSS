# Lambda IAM Role
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda to Access S3 and EC2
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_s3_ec2_policy"
  description = "Policy for Lambda to access S3, EC2, and RDS"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.monika-terraformsss.arn,
          "${aws_s3_bucket.monika-terraformsss.arn}/*"
        ]
      },
      {
        Action = "ec2:DescribeInstances"
        Effect = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}


# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Lambda Function
resource "aws_lambda_function" "file_upload_lambda" {
  function_name = "file_upload_lambda"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "lambda_function.lambda_handler"
  filename      = "lambda_function.zip" # Path to your packaged Lambda function

  # Lambda environment variables
  environment {
    variables = {
      S3_BUCKET_NAME = aws_s3_bucket.monika-terraformsss.bucket
      MYSQL_HOST = aws_instance.web_server.public_ip  # Use the existing EC2 instance resource directly
      MYSQL_USER     = "admin"
      MYSQL_PASSWORD = "tobeornot"
      MYSQL_DB       = "filedb"
    }
  }
}

# Lambda Permission for API Gateway to Invoke Lambda
resource "aws_lambda_permission" "allow_api_gateway" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.file_upload_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  #source_arn = "${aws_apigatewayv2_api.file_upload_http_api.execution_arn}/routes/${aws_apigatewayv2_route.file_upload_route.id}/*"
  source_arn = "${aws_apigatewayv2_api.file_upload_http_api.execution_arn}/*/*"
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "file_upload_http_api" {
  name          = "file-upload-http-api"
  protocol_type = "HTTP"
}

# API Gateway Lambda Integration
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                  = aws_apigatewayv2_api.file_upload_http_api.id
  integration_type        = "AWS_PROXY"  # Use AWS_PROXY to invoke Lambda directly
  integration_uri         = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.file_upload_lambda.arn}/invocations"
  payload_format_version  = "2.0"  # Use 2.0 format for HTTP APIs
}

# API Gateway HTTP API Route (POST /upload)
resource "aws_apigatewayv2_route" "file_upload_lambda" {
  api_id    = aws_apigatewayv2_api.file_upload_http_api.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# API Gateway HTTP API Stage (Auto-deployed)
resource "aws_apigatewayv2_stage" "file_upload_stage" {
  api_id      = aws_apigatewayv2_api.file_upload_http_api.id
  name        = "prod"
  auto_deploy = true  # Automatically deploy the API to this stage
}
