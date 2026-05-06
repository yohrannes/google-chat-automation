resource "aws_lambda_layer_version" "python_dependencies" {
  filename   = "${path.module}/lambda-layers/python-dependencies.zip"
  layer_name = "python-dependencies"

  compatible_runtimes = ["python3.9"]

  depends_on = [null_resource.create_lambda_layer]
}

resource "null_resource" "create_lambda_layer" {
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/lambda-layers/python
      pip install pymysql requests -t ${path.module}/lambda-layers/python/
      find ${path.module}/lambda-layers/python/ -type d -name "__pycache__" -exec rm -rf {} +
      find ${path.module}/lambda-layers/python/ -type d -name "tests" -exec rm -rf {} +
      find ${path.module}/lambda-layers/python/ -type f -name "*.pyc" -delete
      find ${path.module}/lambda-layers/python/ -type d -name "*.dist-info" -exec rm -rf {} +
      find ${path.module}/lambda-layers/python/ -type d -name "*.egg-info" -exec rm -rf {} +
      cd ${path.module}/lambda-layers && zip -r python-dependencies.zip python/
    EOT
  }
}

resource "aws_lambda_function" "lambda-function" {
  filename      = "${path.module}/lambda-functions/lambda-function.zip"
  function_name = "${var.function_name}"
  description   = "Lambda function for ${var.function_name}"
  handler       = "coleta-uptimerobot.lambda_handler"
  role          = module.iam_roles.lambda_role_arn
  runtime       = "python3.9"
  timeout       = 900
  memory_size   = 1024

  vpc_config {
    subnet_ids         = ["subnet-08626e5ac3132693f"]
    security_group_ids = ["sg-0c102d9d64cdd9db9"]
  }

  layers = [aws_lambda_layer_version.python_dependencies.arn]

  depends_on = [null_resource.zip_lambda_functions]
  
  publish = true
}

#resource "aws_lambda_provisioned_concurrency_config" "provisioned" {
#  function_name                     = aws_lambda_function.lambda-function.function_name
#  provisioned_concurrent_executions = 1
#  qualifier                         = aws_lambda_function.lambda-function.version
#}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = module.event_bridge_triggers.cron_trigger_name
  target_id = "${var.function_name}"
  arn       = aws_lambda_function.lambda-function.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda-function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = module.event_bridge_triggers.cron_trigger_arn
}