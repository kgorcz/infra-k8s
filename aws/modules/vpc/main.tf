
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_eip" "nat" {
  vpc = true
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${aws_subnet.public_subnet.id}"
  depends_on = [aws_eip.nat]
}

resource "aws_subnet" "public_subnet" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "10.0.0.0/20"
  availability_zone = "${var.availability_zone}"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "10.0.16.0/20"
  availability_zone = "${var.availability_zone}"
}

resource "aws_route_table" "route_public" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }
}

resource "aws_route_table" "route_private" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.ngw.id}"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.public_subnet.id}"
  route_table_id = "${aws_route_table.route_public.id}"
}

resource "aws_route_table_association" "private" {
  subnet_id      = "${aws_subnet.private_subnet.id}"
  route_table_id = "${aws_route_table.route_private.id}"
}

output "public_subnet_id" {
  depends_on = [aws_route_table_association.public]
  value = "${aws_subnet.public_subnet.id}"
}

output "private_subnet_id" {
  depends_on = [aws_route_table_association.private]
  value = "${aws_subnet.private_subnet.id}"
}

output "vpc_id" {
  value = "${aws_vpc.main.id}"
}
