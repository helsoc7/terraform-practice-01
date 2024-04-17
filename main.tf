provider "aws" {
  region = "eu-central-1"
}

# Modul für das VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws" 

  name = "PodInfoVPC"
  cidr = "10.0.0.0/16"

  azs             = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]  
  public_subnets  = ["10.0.1.0/24"]
}

# Modul für die EC2-Instanz
module "ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name           = "PodInfoInstance"
  ami            = "ami-0f7204385566b32d0"  # Ersetzen Sie dies durch eine gültige AMI-ID für Ihre Region
  instance_type  = "t2.micro"
  subnet_id      = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.ec2-sg-podinfo.id]

  associate_public_ip_address = true
  user_data = <<-EOF
                #!/bin/bash
                sudo yum update -y
                sudo yum install -y docker
                sudo service docker start
                sudo docker run -d -p 80:9898 stefanprodan/podinfo
                EOF
}

resource "aws_security_group" "ec2-sg-podinfo" {
    name = "ec2-sg-podinfo"
    vpc_id = module.vpc.vpc_id

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
  
}

output "public_ip" {
  value = module.ec2.public_ip
}
