data "template_file" "master_cloud_config" {
    template = "${file("master.yml")}"
    vars {
        worker_bootk8s_key = "${file("id_rsa_worker.pub")}"
        bootport_private_key_b64 = "${file("id_rsa_port.b64")}"
        bootport_public_key_b64 = "${file("id_rsa_port.pub.b64")}"
    }
}
data "template_file" "finish_bootstrap" {
    template = "${file("bootstrap-finish.sh")}"
    vars {
        domain_name = "${var.domain_name}"
        letsencrypt_email = "${var.letsencrypt_email}"
        node_count = "${var.worker_count}"
    }
}

data "template_cloudinit_config" "master_cloud_init" {
    part {
        content_type = "text/cloud-config"
        content = "${data.template_file.master_cloud_config.rendered}"
    }
    part {
        content_type = "text/x-shellscript"
        content = "${file("bootstrap-master.sh")}"
    }
    part {
        content_type = "text/x-shellscript"
        content = "${data.template_file.join_teleport.rendered}"
    }
    part {
        content_type = "text/x-shellscript"
        content = "${data.template_file.setup_teleport_k8s.rendered}"
    }
    part {
        content_type = "text/x-shellscript"
        content = "${data.template_file.finish_bootstrap.rendered}"
    }
}

resource "aws_instance" "master_node" {
    ami = "ami-00c5940f2b52c5d98"
    instance_type = "t2.medium"
    subnet_id = "${var.private_subnet_id}"
    vpc_security_group_ids = ["${aws_security_group.asg_private.id}"]
    key_name = "${var.key_name}"
    root_block_device {
      volume_size = 16
    }

    user_data = "${data.template_cloudinit_config.master_cloud_init.rendered}"

    tags {
        Name = "${var.cluster_name}-master"
    }
}

output "master_ip" {
  value = "${aws_instance.master_node.private_ip}"
}
