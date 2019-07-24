resource "aws_lb" "nlb" {
  name               = "${var.cluster_name}-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets = ["${var.public_subnet_id}"]
  #enable_cross_zone_load_balancing = true
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = "${aws_lb.nlb.arn}"
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.http_target.arn}"
  }
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = "${aws_lb.nlb.arn}"
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.https_target.arn}"
  }
}

resource "aws_lb_listener" "dicom_listener" {
  load_balancer_arn = "${aws_lb.nlb.arn}"
  port              = "104"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.dicom_target.arn}"
  }
}

resource "aws_lb_target_group" "http_target" {
  name     = "ter-http-target"
  port     = 32323
  protocol = "TCP"
  vpc_id   = "${var.vpc_id}"
}

resource "aws_lb_target_group_attachment" "nlb_attachment_http" {
  target_group_arn = "${aws_lb_target_group.http_target.arn}"
  target_id        =  "${element(aws_instance.worker_node.*.id, count.index)}"
  count = "${var.worker_count}"
}

resource "aws_lb_target_group" "https_target" {
  name     = "ter-https-target"
  port     = 32324
  protocol = "TCP"
  vpc_id   = "${var.vpc_id}"
}

resource "aws_lb_target_group_attachment" "nlb_attachment_https" {
  target_group_arn = "${aws_lb_target_group.https_target.arn}"
  target_id        =  "${element(aws_instance.worker_node.*.id, count.index)}"
  count = "${var.worker_count}"
}


resource "aws_lb_target_group" "dicom_target" {
  name     = "ter-dicom-target"
  port     = 32325
  protocol = "TCP"
  vpc_id   = "${var.vpc_id}"
}

resource "aws_lb_target_group_attachment" "nlb_attachment_dicom" {
  target_group_arn = "${aws_lb_target_group.dicom_target.arn}"
  target_id        =  "${element(aws_instance.worker_node.*.id, count.index)}"
  count = "${var.worker_count}"
}

output "load_balancer" {
    value = "${aws_lb.nlb.dns_name}"
}
