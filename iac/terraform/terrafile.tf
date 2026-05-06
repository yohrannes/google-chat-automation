module "event_bridge_triggers" {
  source = "./modules/event-bridge-triggers"
  cron = "0/5 * ? * * *"
  function_name = var.function_name
}

module "iam_roles" {
  source        = "./modules/iam_roles"
  aws_region    = "sa-east-1"
  function_name = var.function_name
}