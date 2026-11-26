output "state_bucket" {
  description = "Nome do bucket que guarda o state da infraestrutura da aplicação."
  value       = data.aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN do bucket de state."
  value       = data.aws_s3_bucket.state.arn
}

output "init_command" {
  description = "Comando de init da raiz apontando para este bucket (ou use scripts/iniciar-terraform.sh)."
  value       = "terraform init -backend-config=\"bucket=${data.aws_s3_bucket.state.id}\" -backend-config=\"region=${var.aws_region}\""
}
