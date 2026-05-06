resource "null_resource" "zip_lambda_functions" {
  provisioner "local-exec" {
    command = <<EOT
      zip -j ${path.module}/lambda-functions/lambda-function.zip ${path.module}/lambda-functions/${var.function_name}.py
    EOT
  }
}