resource "aws_s3_bucket" "terraform_state" {
  #checkov:skip=CKV2_AWS_62:Terraform state is not an event source; access is controlled by IAM and the bucket policy.
  #checkov:skip=CKV2_AWS_61:State versions are retained for recovery; automatic expiration would undermine rollback.
  #checkov:skip=CKV_AWS_18:Access logging requires a separate logging bucket and is outside the bootstrap contract.
  #checkov:skip=CKV_AWS_144:Cross-region replication requires a second-region recovery design and is not enabled by default.
  #checkov:skip=CKV_AWS_145:AES256 server-side encryption satisfies the repository state-encryption requirement without introducing a second billable CMK.
  bucket        = var.state_bucket_name
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.terraform_state.arn, "${aws_s3_bucket.terraform_state.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

resource "aws_dynamodb_table" "terraform_locks" {
  #checkov:skip=CKV_AWS_119:AWS-managed server-side encryption satisfies the lock-table encryption requirement; a customer CMK is not required for the lock metadata.
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }
}
