output "instance_id" {
  description = "EC2 Instance ID"
  value = aws_instance.dojo-007-ec2-web.id
}

output "public_ip" {
  description = "Web IP"
  value = aws_instance.dojo-007-ec2-web.public_ip
}

output "security_group_id" {
  description = "Security Group for Web Server"
  value = aws_security_group.dojo-007-sg-web.id
}

output "bastion_instance_id" {
  description = "Bastion Server ID"
  value = aws_instance.dojo-007-ec2-bastion.id
}

output "bastion_security_group_id" {
  description = "Security Group for Bastion Server"
  value = aws_security_group.dojo-007-sg-bastion.id
}