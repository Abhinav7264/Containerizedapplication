resource "aws_dynamodb_table" "state_dynamodb" {
    name = "humangov-${var.state_name}-dynamodb"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "id"

    attribute {
        name = "id"
        type = "S"
    }

    tags = {
        Name = "humangov-${var.state_name}"
    }
}

resource "random_string" "bucket_suffix" {
    length = 4
    special = false
    upper = false
}

resource "aws_s3_bucket" "state_s3" {
    bucket = "humangov-${var.state_name}-s3-${random_string.bucket_suffix.result}"

    tags = {
        Name = "humangov-${var.state_name}"
    }
}