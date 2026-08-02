output "state_bucket_name" {
  description = "S3 bucket to configure in each environment backend."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "lock_table_name" {
  description = "DynamoDB table to configure for Terraform locking."
  value       = aws_dynamodb_table.terraform_locks.name
}
