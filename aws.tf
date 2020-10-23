resource "aws_vpc" "vpc" {
  cidr_block       = "10.2.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "vpc_task3"
  }
}

resource "aws_subnet" "pub_subnet" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.2.1.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "priv_subnet" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.2.2.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "private-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "private-rt"
  }
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "task3-ig"
  }
}

resource "aws_eip" "nat_eip" {
  tags = {
    Name = "task3-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.pub_subnet.id

  tags = {
    Name = "task3-NAT"
  }
}

resource "aws_route_table_association" "rt_pub_subnet" {
  subnet_id      = aws_subnet.pub_subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "rt_priv_subnet" {
  subnet_id      = aws_subnet.priv_subnet.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route" "route-ig" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.ig.id
}

resource "aws_route" "route-nat" {
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id            = aws_nat_gateway.nat.id
}

resource "tls_private_key" "task3_key"  {
  algorithm = "RSA"
}

resource "aws_key_pair" "keypair" {
  key_name = "cloud_task3_key"
  public_key = tls_private_key.task3_key.public_key_openssh
}

resource "local_file" "download_key" {
  content = tls_private_key.task3_key.private_key_pem
  filename = "cloud_task3_key.pem"
}

resource "aws_security_group" "sg_wp" {
  name        = "wordpress-sg"
  description = "Allow HTTP and SSH inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_http"
  }
}

resource "aws_security_group" "sg_mysql" {
  name        = "mysql-sg"
  description = "Allow MySQL inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Allow MySQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [ "${aws_instance.wordpress.private_ip}/32" ]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_mysql_ssh"
  }
}

resource "aws_instance" "wordpress" {
  ami           = "ami-049609235004b64bc"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.pub_subnet.id
  associate_public_ip_address = true
  key_name = aws_key_pair.keypair.key_name
  security_groups = [ aws_security_group.sg_wp.id ]
  tags = {
    Name = "Wordpress"
  }
}

resource "aws_instance" "mysql" {
  ami           =  "ami-0df8aa28f5a7d2957"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.priv_subnet.id
  associate_public_ip_address = false
  key_name = aws_key_pair.keypair.key_name
  security_groups = [ aws_security_group.sg_mysql.id ]
  tags = {
    Name = "MySQL"
  }
}

output "ip_wordpress" {
  value = aws_instance.wordpress.public_ip
}
output "ip_mysql" {
  value = aws_instance.mysql.private_ip
}