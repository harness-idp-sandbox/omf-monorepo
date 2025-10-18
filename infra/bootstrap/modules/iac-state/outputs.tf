# Raw pieces
output "bucket_name" {
  description = "Name of the S3 bucket used for Terraform state."
  value       = aws_s3_bucket.tf.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket used for Terraform state."
  value       = aws_s3_bucket.tf.arn
}

output "dynamodb_table" {
  description = "Name of the DynamoDB table for state locking."
  value       = aws_dynamodb_table.locks.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for state locking."
  value       = aws_dynamodb_table.locks.arn
}

output "region" {
  description = "AWS region where the backend lives."
  value       = var.region
}

# Ready-to-attach policy JSON for your OIDC role (backend access only)
output "backend_access_policy_json" {
  description = "IAM policy JSON for S3 object and DynamoDB table access used by Terraform backend."
  value       = data.aws_iam_policy_document.backend_access.json
}

# Handy template for backend.hcl that your repo workflows can fill in with an app-specific key
output "backend_hcl_example" {
  description = "Example backend.hcl content for initializing Terraform with this backend."
  value       = <<EOT
bucket         = "${aws_s3_bucket.tf.bucket}"
key            = "${var.state_key_prefix}/<app-path>/terraform.tfstate"
region         = "${var.region}"
dynamodb_table = "${aws_dynamodb_table.locks.name}"
encrypt        = true
EOT
}

# A consolidated view you can query from scripts
output "backend_metadata" {
  description = "Convenient map of backend values (bucket, dynamodb, region)."
  value = {
    bucket         = aws_s3_bucket.tf.bucket
    bucket_arn     = aws_s3_bucket.tf.arn
    dynamodb_table = aws_dynamodb_table.locks.name
    dynamodb_arn   = aws_dynamodb_table.locks.arn
    region         = var.region
  }
}
