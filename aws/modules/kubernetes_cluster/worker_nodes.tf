
data "cloudinit_config" "worker_cloud_init" {
    part {
        content_type = "text/cloud-config"
        content = templatefile("${path.module}/worker.yml", {
            worker_private_key_b64 = "${base64encode(file("pki/id_rsa_worker"))}"
            worker_public_key_b64 = "${base64encode(file("pki/id_rsa_worker.pub"))}"
            bootport_private_key_b64 = "${base64encode(file("pki/id_rsa_port"))}"
            bootport_public_key_b64 = "${base64encode(file("pki/id_rsa_port.pub"))}"
        })
    }
    part {
        content_type = "text/x-shellscript"
        content = templatefile("scripts/bootstrap-worker.sh", {
            master_ip = "${aws_instance.master_node.private_ip}"
        })
    }
    part {
        content_type = "text/x-shellscript"
        content = local.join_teleport
    }
}

resource "aws_instance" "worker_node" {
    ami = "ami-05bad978b2cf5d78c"
    instance_type = "t3a.medium"
    subnet_id = "${var.private_subnet_id}"
    vpc_security_group_ids = ["${aws_security_group.asg_private.id}"]
    key_name = "${var.key_name}"
    user_data = "${data.cloudinit_config.worker_cloud_init.rendered}"
    root_block_device {
      volume_size = 16
    }

    count = "${var.worker_count}"

    tags = {
        Name = "${var.cluster_name}-worker-${count.index}"
    }
}
