terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region       = "eu-west-3"
  access_key   = var.access_key
  secret_key   = var.secret_key
}


#create vpc
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    "Name" = "production"
  }
}


#create internet gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "prod-gw"
  }
}

#create a route table

resource "aws_route_table" "r" {
  #vpc_id = module.vpc.prod-vpc
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    #ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "store"
  }
}

  #locals {

  #routes_helper = [
      #for route in var.routes: merge({
          #carrier_gateway_id = null
          #destination_prefix_list_id = null
          #egress_only_gateway_id = null 
          #ipv6_cidr_block = null 
          #local_gateway_id = null
          #nat_gateway_id = null
          #network_interface_id = null
          #transit_gateway_id = null 
          #vpc_endpoint_id = null 
          #instance_id = null
          #gateway_id = null
          #vpc_peering_connection_id = null
      #}, route)
    #]

#}
  
  
#}


#create a subnet

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-3a"

  tags = {
    Name = "prod subnet"
  }
}
#associate subnet with route table

resource "aws_route_table_association" "rt-asso" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.r.id
}
#resource "aws_route_table_association" "b" {
  #gateway_id     = aws_internet_gateway.gw.id
  #route_table_id = aws_route_table.r.id
#}


#create security group 22,80,443

resource "aws_security_group" "allow-web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress = [
    {
      description      = "HTTPS"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self = true
    },
    {
      description      = "HTTP"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self = true
    },
    {
      description      = "SSH"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self = true
    },
    
  ]

  egress = [
    {
      description      = ""
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self = true
    }
  ]

  tags = {
    Name = "allow-web"
  }
}

#create a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow-web.id]

}

#assign an elastic ip to the network interface created in step 7

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}

#create ubuntu server and install/enale apache2

resource "aws_instance" "web-server-instance" {
  ami = "ami-0f7cd40eac2214b37"
  instance_type = "t2.micro"
  availability_zone = "eu-west-3a"
  key_name = "chukaKey"
  depends_on                = [aws_internet_gateway.gw]

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
  #!/bin/bash
  sudo apt update -y
  sudo apt install apache2 -y
  sudo systemctl start apache2
  sudo bash -c 'echo your very first web server > /var/www/html/index.html'
  EOF

    tags = {
      Name = "web-server-1"
    }          
}