data "template_file" "worker_cloud_config" {
    template = "${file("worker.yml")}"
    vars {
        worker_private_key_b64 = "${file("id_rsa_worker.b64")}"
        worker_public_key_b64 = "${file("id_rsa_worker.pub.b64")}"
        bootport_private_key_b64 = "${file("id_rsa_port.b64")}"
        bootport_public_key_b64 = "${file("id_rsa_port.pub.b64")}"
    }
}

data "template_file" "worker_bootstrap" {
    template = "${file("bootstrap-worker.sh")}"
    vars {
        master_ip = "${aws_instance.master_node.private_ip}"
    }
}

data "template_cloudinit_config" "worker_cloud_init" {
    part {
        content_type = "text/cloud-config"
        content = "${data.template_file.worker_cloud_config.rendered}"
    }
    part {
        content_type = "text/x-shellscript"
        content = "${data.template_file.worker_bootstrap.rendered}"
    }
    part {
        content_type = "text/x-shellscript"
        content = "${data.template_file.join_teleport.rendered}"
    }
}

resource "aws_instance" "worker_node" {
    ami = "ami-00c5940f2b52c5d98"
    instance_type = "t2.medium"
    subnet_id = "${var.private_subnet_id}"
    vpc_security_group_ids = ["${aws_security_group.asg_private.id}"]
    key_name = "${var.key_name}"
    user_data = "${data.template_cloudinit_config.worker_cloud_init.rendered}"
    root_block_device {
      volume_size = 16
    }

    count = "${var.worker_count}"

    tags {
        Name = "${var.cluster_name}-worker-${count.index}"
    }
}
