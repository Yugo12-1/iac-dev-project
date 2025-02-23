# providerの設定
provider "aws" {
  region     = "ap-northeast-1"
  access_key = var.iac-dev-access-key
  secret_key = var.iac-dev-secret-key
}


# 変数定義一覧
variable "iac-dev-access-key" {
  description = "awsプラグイン用のaccess-key"
}

variable "iac-dev-secret-key" {
  description = "awsプラグイン用のsecret-key"
}


#1. vpcの作成
resource "aws_vpc" "iac-dev-vpc-web" {
  cidr_block       = "10.0.0.0/16"
  tags = {
    Name           = "iac-dev-vpc-web"
  }
}


#2. subnetの作成
## public
resource "aws_subnet" "iac-dev-subnet-public-a" {
  vpc_id            = aws_vpc.iac-dev-vpc-web.id
  availability_zone = "ap-northeast-1a"
  cidr_block        = "10.0.1.0/24"

  tags = {
    Name            = "iac-dev-subnet-public-a"
  }
}

#2-2 alb用サブネット
resource "aws_subnet" "iac-dev-subnet-public-c" {
  vpc_id            = aws_vpc.iac-dev-vpc-web.id
  availability_zone = "ap-northeast-1c"
  cidr_block        = "10.0.2.0/24"

  tags = {
    Name            = "iac-dev-subnet-public-c"
  }
}

#3. internet gatewayの作成
resource "aws_internet_gateway" "iac-dev-igw-web" {
  vpc_id = aws_vpc.iac-dev-vpc-web.id

  tags = {
    Name = "iac-dev-igw-web"
  }
}


#4. route tableの作成（public subnet用)
resource "aws_route_table" "iac-dev-rt-public" {
  vpc_id = aws_vpc.iac-dev-vpc-web.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.iac-dev-igw-web.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.iac-dev-igw-web.id
  }
  tags = {
    Name = "iac-dev-rt-public"
  }
}


#4-2. route tableとpublic subnetの関連付け
resource "aws_route_table_association" "iac-dev-rt-as-public-a" {
  subnet_id      = aws_subnet.iac-dev-subnet-public-a.id
  route_table_id = aws_route_table.iac-dev-rt-public.id
}


#5. セキュリティグループの作成（port 22, 80, 443を許可）
resource "aws_security_group" "iac-dev-sg-web" {
  name        = "iac-dev-sg-web"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.iac-dev-vpc-web.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "iac-dev-sg-web"
  }
}


#5-2. セキュリティグループの作成（port22, 80を許可）
resource "aws_security_group" "iac-dev-sg-login" {
  name        = "iac-dev-sg-login"
  description = "Allow ssh access for administrator"
  vpc_id      = aws_vpc.iac-dev-vpc-web.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "iac-dev-sg-login"
  }
}


#6 ロードバランサーを作成（ALB)
resource "aws_lb" "iac-dev-alb-web" {
  name               = "iac-dev-alb-web"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.iac-dev-sg-web.id]
  subnets            = [aws_subnet.iac-dev-subnet-public-a.id, aws_subnet.iac-dev-subnet-public-c.id]

  tags = {
    Name             = "iac-dev-alb-web"
  }
}

#7 ターゲットグループの作成
resource "aws_lb_target_group" "iac-dev-lb-target-group" {
  name     = "iac-dev-lb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.iac-dev-vpc-web.id
}

#7-2 ターゲットグループのリソースアタッチ
resource "aws_lb_target_group_attachment" "iac-dev-lb-attach" {
  target_group_arn = aws_lb_target_group.iac-dev-lb-target-group.arn
  target_id        = aws_instance.iac-dev-ec2-web1.id
  port            = 80
}

resource "aws_lb_target_group_attachment" "iac-dev-lb-attach2" {
  target_group_arn = aws_lb_target_group.iac-dev-lb-target-group.arn
  target_id        = aws_instance.iac-dev-ec2-web2.id
  port            = 80
}

#7-3 albリスナーの設定
resource "aws_lb_listener" "iac-dev-lb-listener" {
  load_balancer_arn = aws_lb.iac-dev-alb-web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.iac-dev-lb-target-group.arn
  }
}


#8 eipの作成 ansibleマスター用
resource "aws_eip" "iac-dev-eip-ansible" {
  domain = "vpc"
  instance = aws_instance.iac-dev-ec2-ansible.id
  # network_interface = aws_network_interface.iac-dev-eni-ansible.id
  # associate_with_private_ip = "10.0.1.10"
  # depends_on = [aws_internet_gateway.iac-dev-igw-web, aws_instance.iac-dev-ec2-ansible]
}


# #9 ENI（Elastic Network Interface）作成　ansibleマスター用
# resource "aws_network_interface" "iac-dev-eni-ansible" {
#   subnet_id       = aws_subnet.iac-dev-subnet-public-a.id
#   private_ips     = ["10.0.1.10"]
#   security_groups = [aws_security_group.iac-dev-sg-login.id]
# }


#10 EC2インスタンスの作成  ansibleマスター用
resource "aws_instance" "iac-dev-ec2-ansible" {
  ami             = "ami-072298436ce5cb0c4"  #Amazon Linux 2023
  instance_type   = "t2.micro"
  key_name        = "iac-dev-key"
  subnet_id       = aws_subnet.iac-dev-subnet-public-a.id
  security_groups = [aws_security_group.iac-dev-sg-login.id]
  associate_public_ip_address = true

  # network_interface {
  #   device_index = 0
  #   network_interface_id = aws_network_interface.iac-dev-eni-ansible.id
  # }

  tags = {
    Name = "iac-dev-ec2-ansible"
  }
}

#10 EC2インスタンスの作成  webサーバー
resource "aws_instance" "iac-dev-ec2-web1" {
  ami             = "ami-072298436ce5cb0c4"  #Amazon Linux 2023
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.iac-dev-subnet-public-a.id
  key_name        = "iac-dev-key"
  security_groups = [aws_security_group.iac-dev-sg-web.id]
  associate_public_ip_address = true

  tags = {
    Name = "iac-dev-ec2-web1"
  }
}

resource "aws_instance" "iac-dev-ec2-web2" {
  ami             = "ami-072298436ce5cb0c4"  #Amazon Linux 2023
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.iac-dev-subnet-public-a.id
  key_name        = "iac-dev-key"
  security_groups = [aws_security_group.iac-dev-sg-web.id]
  associate_public_ip_address = true

  tags = {
    Name = "iac-dev-ec2-web2"
  }
}