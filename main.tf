# Generate random string as prefix to all resources
resource "random_string" "prefix" {
  length  = 5
  special = false
  upper   = true
  lower   = false
  numeric = false
}

# Generate resource group
resource "aws_resourcegroups_group" "rg" {
  name        = var.resource_group_name
  description = "Resource Group for ${var.resource_tags.use_case}"

  resource_query {
    query = <<JSON
    {
      "ResourceTypeFilters": [
        "AWS::AllSupported"
      ],
      "TagFilters": [
        {
          "Key": "owner",
          "Values": [
            "${var.resource_tags.owner}"
          ]
        },
        {
          "Key": "email",
          "Values": [
            "${var.resource_tags.email}"
          ]
        },
        {
          "Key": "use_case",
          "Values": [
            "${var.resource_tags.use_case}"
          ]
        }
      ]
    }
    JSON
  }
}

# Generate security group
resource "aws_security_group" "sg" {
  name        = "${random_string.prefix.result}-sg"
  description = "Security Group for ${var.resource_tags.use_case}"
  vpc_id      = aws_vpc.vpc.id

  tags = var.resource_tags
}

# Generate security group rule for ingress http
resource "aws_security_group_rule" "ingress-http" {
  description       = "ingress-http"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.sg.id
}

# Generate security group rule for ingress ssh
resource "aws_security_group_rule" "ingress-ssh" {
  description       = "ingress-ssh"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.sg.id
}

# Generate security group rule for egress all
resource "aws_security_group_rule" "egress-all" {
  description       = "egress-all"
  type              = "egress"
  to_port           = 0
  protocol          = "-1"
  from_port         = 0
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.sg.id
}

# Generate virtual public cloud (vnet)
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = var.resource_tags
}

# Generate subnet
resource "aws_subnet" "subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.subnet_cidr
  availability_zone = var.aws_availability_zone

  tags = var.resource_tags
}

# Generate route table
resource "aws_route_table" "public-route" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "public-route"
  }
}

# Generate internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = var.resource_tags
}

# Generate route for internet access
resource "aws_route" "internet-access" {
  route_table_id         = aws_route_table.public-route.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id

}

# Associate route table to subnet
resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.public-route.id
}

# Generate network interface card
resource "aws_network_interface" "internal" {
  subnet_id = aws_subnet.subnet.id

  tags = var.resource_tags
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Generate public key
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Generate key pair
resource "aws_key_pair" "key" {
  key_name   = "key1"
  public_key = tls_private_key.rsa.public_key_openssh
}

# Generate ec2 instance for webserver
resource "aws_instance" "instance" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  availability_zone           = var.aws_availability_zone
  subnet_id                   = aws_subnet.subnet.id
  private_ip                  = var.private_ip
  associate_public_ip_address = true
  key_name                    = aws_key_pair.key.key_name
  user_data = filebase64("${path.module}/external/web.conf") #nginx webserver setup config

  tags = var.resource_tags
}

# Attach network interface to security group
resource "aws_network_interface_sg_attachment" "sg_attachment" {
  security_group_id    = aws_security_group.sg.id
  network_interface_id = aws_instance.instance.primary_network_interface_id
}

# Store the private key to file for future use
resource "local_file" "prefix" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "key1.pem"
}

output "ec2_pip" {
  value = ["${aws_instance.instance.public_ip}"]
}
