data "template_file" "master_cloud_config" {
    template = "${file("${path.module}/master.yml")}"
    vars {
        worker_bootk8s_key = "${file("pki/id_rsa_worker.pub")}"
        bootport_private_key_b64 = "${base64encode(file("pki/id_rsa_port"))}"
        bootport_public_key_b64 = "${base64encode(file("pki/id_rsa_port.pub"))}"
    }
}

data "template_file" "finish_bootstrap" {
    template = "${file("scripts/bootstrap-finish.sh")}"
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
        content = "${file("scripts/bootstrap-master.sh")}"
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
    ami = "ami-07eec5e1e50b54d0f"
    instance_type = "t3a.medium"
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
