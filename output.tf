output "instance_ip" {
  value = aws_instance.web_server.public_ip
}

output "api_gateway" {
  description = "The URL of the API Gateway endpoint"
  value       = aws_apigatewayv2_stage.file_upload_stage.invoke_url
}
