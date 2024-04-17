# EC2 Instanz mit Terraform erstellen
---
Wir erstellen eine EC2-Instanz mit Terraform. Dazu soll ein VPC mit einem public Subnet erstellt werden. Die EC2-Instanz soll eine public IP-Adresse bekommen und über ein Terraform so konfiguriert werden, dass der Podinfo Docker Container auf der Instanz läuft und die Weboberfläche des Containers über die IP abrufbar ist.  

Wir nutzen dazu die Terraform AWS Module VPC und EC2
### Module in Terraform
Wir nutzen Module, um wiederverwendbare, vordefinierte Komponenten für spezifische Aufgaben, wie das Erstellen eines VPCs oder das Bereitstellen eineer EC2-Instanz, zu nutzen. Das heißt Module sind wiederverwendbare Komponenten, die es ermöglichen, eine Gruppe von Ressourcen, die logisch zusammengehören, in einer einzigen Einheit zu definieren und zu verwalten. 
#### VPC Modul:
Das VPC Modul ist verantwortlich für die Erstellung eines VPC-Netzwerks in AWS. Es definiert das VPC selbst, aber kann auch Subnetze, Internet Gateways, Route Tables und andere Netzwerkkomponenten erstellen und konfigurieren.
#### EC2 Modul:
Das EC2 Modul ermöglicht die Erstellung von EC2-Instanzen in AWS. Es handhabt dabei Details wie die Auswahl der AMI, die Instanzgröße, das Netzwerk, in dem die Instanz gestartet wird und zusätzliche Konfigurationen wie SSH-Zugriff und Security Groups.

## Anleitung
1. Wir stellen sicher, dass Terraform installiert ist mit `terraform -v`. Außerdem müssen die AWS-Zugangsdaten konfiguriert werden. Das geht entweder über Umgebungsvariablen oder über die AWS CLI. Führe ein `aws sso login` aus, wenn du ein Profil hinterlegt hast in der AWS CLI.
2. Als nächstes erstellen wir uns und Terraform-Konfigurationsdatei `main.tf`, die eben die Module für VPC und EC2 verwendet. Dazu müssen wir noch zusätzliche Ressourcen und Anbieterinformationen angeben.
3. Wir starten in unserer `main.tf`-Datei mit dem provider. Wir nutzen hier aws als Provider in der Region eu-central-1
```
provider "aws" {
  region = "eu-central-1"
}
```
4. Als nächstes erstellen wir das Modul VPC, in dem wir zunächst die Source angeben aus der offiziellen Terraform-Dokumentation. Außerdem brauchen wir einen Namen, ein CIDR, die AZs und public Subnets.
```
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws" 

  name = "PodInfoVPC"
  cidr = "10.0.0.0/16"

  azs             = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]  
  public_subnets  = ["10.0.1.0/24"]
}
```
5. Das nächste Modul ist das für die EC2-Instanz. Hier benötigen wir ein paar mehr Informationen. Zunächst erstmal die wesentlichen: Die Source aus der Dokumentation, den Namen, ein AMI, den Instanz-Typ und die Subnet-ID, die wir aus dem VPC-Modul entnehmen (Zugriff mit `module.vpc.public_subnets[0]`). Ferner werden noch Security Groups, die wir gleich als Ressource definieren wollen. Ferner wird das Zuordnen einer public IP enabled und ein User-Data-Script angegeben, das docker installiert, startet und das Docker-Image Podinfo pullt und in einem Container laufen lässt. 
```
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
```
6. Im nächsten Schritt definieren wir die Security Groups für die EC2-Instanz als Ressource mit dem Namen `ec2-sg-podinfo`. Wir müssen der Security Group das erstellte VPC zuordnen und definieren 2 Ingress-Rules (jeweils HTTP und SSH-Zugriff von überall zugelassen). Außerdem soll der Egress nach überall möglich sein.
```
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
```
7. Als letztes definieren wir noch einen Output und zwar die public-IP, über die wir unsere EC2-Instanz erreichen können.
```
output "public_ip" {
  value = module.ec2.public_ip
}
```
8. Führe ein `tf init`, ein `tf plan` und ein `tf apply` aus. Über die ausgegebene IP sollte ein süßes Bildchen von einem quallenartigen Geschöpf ausgegeben werden. 
