output "vpc_id" {
  value = aws_vpc.exam_vpc.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "ec2_instance_id" {
  value = aws_instance.web.id
}

output "ec2_public_ip" {
  value = aws_instance.web.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.logs.bucket
}

output "kms_key_arn" {
  value = aws_kms_key.s3_key.arn
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.sessions.name
}