terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  # (LocalStack configuration)
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  s3_use_path_style = true

  # אם משתמשים ב-tflocal, הבלוק הזה לא חובה כי tflocal מזריק את ה-endpoints.
  # עם זאת, זה עוזר אם מריצים terraform רגיל מול LocalStack.
  # (Endpoints for standard Terraform usage with LocalStack)
  endpoints {
    ec2        = "http://localhost:4566"
    sts        = "http://localhost:4566"
    s3         = "http://localhost:4566"
    iam        = "http://localhost:4566"
    acm        = "http://localhost:4566"
    cloudfront = "http://localhost:4566"
    route53    = "http://localhost:4566"
  }
}

# (Create VPC)
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

# (Create Internet Gateway for internet access)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main-igw"
  }
}

# (Create Public Subnet)
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true # דואג שהמכונה תקבל Public IP אוטומטית

  tags = {
    Name = "public-subnet"
  }
}

# (Create Route Table)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# (Associate Subnet with Route Table)
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# (Create Security Group)
resource "aws_security_group" "web_ssh_sg" {
  name        = "web-ssh-sg"
  description = "Allow HTTP and SSH traffic"
  vpc_id      = aws_vpc.main_vpc.id

  # כניסה: SSH פורט 22
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # כניסה: HTTP פורט 80
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # כניסה: Custom פורט 5555
  ingress {
    from_port   = 5555
    to_port     = 5555
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # כניסה: ICMP (Ping)
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # יציאה: הכל פתוח
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



locals {
  private_key_path = "${path.module}/ec2_key_pair.pem"
}

# 7. יצירת מפתח פרטי (SSH Private Key) כריסורס רגיל כדי למנוע מחיקה אוטומטית
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 8. יצירת Key Pair ב-AWS
resource "aws_key_pair" "generated_key" {
  key_name   = "ec2_key_pair"
  public_key = tls_private_key.example.public_key_openssh

  lifecycle {
    ignore_changes = [public_key]
  }
}

# 9. שמירת המפתח הפרטי לקובץ מקומי
resource "local_file" "private_key" {
  content         = tls_private_key.example.private_key_pem
  filename        = local.private_key_path
  file_permission = "0400"
}

# (Create EC2 Instance)
resource "aws_instance" "web_server" {
  ami           = "ami-df5de72bdb3b" # Default Ubuntu ID for LocalStack
  instance_type = "t3.micro"
  key_name      = aws_key_pair.generated_key.key_name

  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.web_ssh_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "web-server-test1"
  }
}

# (Setup testuser via Docker exec - bypassing cloud-init issues)
resource "null_resource" "setup_testuser" {
  depends_on = [aws_instance.web_server]

  provisioner "local-exec" {
    command     = "sleep 10 && CONTAINER_ID=$(docker ps -q -f name=localstack-ec2.${aws_instance.web_server.id}) && if [ -n \"$CONTAINER_ID\" ]; then docker exec $CONTAINER_ID bash -c 'useradd -m -s /bin/bash testuser || true; echo \"testuser ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers; mkdir -p /home/testuser/.ssh; if [ -f /root/.ssh/authorized_keys ]; then cp /root/.ssh/authorized_keys /home/testuser/.ssh/authorized_keys; elif [ -f /home/ubuntu/.ssh/authorized_keys ]; then cp /home/ubuntu/.ssh/authorized_keys /home/testuser/.ssh/authorized_keys; fi; chown -R testuser:testuser /home/testuser/.ssh; chmod 700 /home/testuser/.ssh; chmod 600 /home/testuser/.ssh/authorized_keys; echo \"Acquire::ForceIPv4 \\\"true\\\";\" > /etc/apt/apt.conf.d/99force-ipv4; apt-get update -y; apt-get install -y docker.io git python3 python3-pip wget curl openjdk-11-jdk maven; service docker start; curl -L \"https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose; chmod +x /usr/local/bin/docker-compose; wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64; chmod a+x /usr/local/bin/yq'; fi"
    interpreter = ["/bin/bash", "-c"]
  }
}

# (Copy SSH keys to root user and add GitHub to known_hosts)
resource "null_resource" "copy_ssh_keys" {
  depends_on = [null_resource.setup_testuser]

  provisioner "local-exec" {
    command     = "sleep 5 && CONTAINER_ID=$(docker ps -q -f name=localstack-ec2.${aws_instance.web_server.id}) && if [ -n \"$CONTAINER_ID\" ]; then docker exec $CONTAINER_ID mkdir -p /root/.ssh && docker cp ~/.ssh/id_ed25519 $CONTAINER_ID:/root/.ssh/id_ed25519 && docker cp ~/.ssh/id_ed25519.pub $CONTAINER_ID:/root/.ssh/id_ed25519.pub && docker exec $CONTAINER_ID bash -c 'chmod 600 /root/.ssh/id_ed25519 && ssh-keyscan github.com >> /root/.ssh/known_hosts'; fi"
    interpreter = ["/bin/bash", "-c"]
  }
}

# 11. פלטים (Outputs)
output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.web_server.public_ip
}

output "instance_private_ip" {
  description = "Private IP of the EC2 instance"
  value       = aws_instance.web_server.private_ip
}
