data "template_file" "join_teleport" {
    template = "${file("join-teleport.sh")}"
    vars {
        bastion_ip = "${var.bastion_private_ip}"
    }
}

data "template_file" "setup_teleport_k8s" {
    template = "${file("setup-teleport-k8s.sh")}"
    vars {
        bastion_private_ip = "${var.bastion_private_ip}"
        bastion_public_ip = "${var.bastion_public_ip}"
    }
}
