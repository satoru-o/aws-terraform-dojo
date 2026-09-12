output "instance_id" {
  description = "EC2 Instance ID"
  value = aws_instance.dojo-006-ec2.id
}

output "public_ip" {
  description = "Web IP"
  value = aws_instance.dojo-006-ec2.public_ip
}

output "security_group_id" {
  description = "Security Group for Web Server"
  value = aws_security_group.dojo-006-sg.id
}