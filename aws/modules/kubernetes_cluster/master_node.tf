
data "cloudinit_config" "master_cloud_init" {
    part {
        content_type = "text/cloud-config"
        content = templatefile( "${path.module}/master.yml", {
            worker_bootk8s_key = "${file("pki/id_rsa_worker.pub")}"
            bootport_private_key_b64 = "${base64encode(file("pki/id_rsa_port"))}"
            bootport_public_key_b64 = "${base64encode(file("pki/id_rsa_port.pub"))}"
        })
    }
    part {
        content_type = "text/x-shellscript"
        content = "${file("scripts/bootstrap-master.sh")}"
    }
    part {
        content_type = "text/x-shellscript"
        content = local.join_teleport
    }
    part {
        content_type = "text/x-shellscript"
        content = local.setup_teleport_k8s
    }
    part {
        content_type = "text/x-shellscript"
        content = templatefile("scripts/bootstrap-finish.sh", {
            domain_name = "${var.domain_name}"
            letsencrypt_email = "${var.letsencrypt_email}"
            node_count = "${var.worker_count}"
        })
    }
}

resource "aws_instance" "master_node" {
    ami = "ami-05bad978b2cf5d78c"
    instance_type = "t3a.medium"
    subnet_id = "${var.private_subnet_id}"
    vpc_security_group_ids = ["${aws_security_group.asg_private.id}"]
    key_name = "${var.key_name}"
    root_block_device {
      volume_size = 16
    }

    user_data = "${data.cloudinit_config.master_cloud_init.rendered}"

    tags = {
        Name = "${var.cluster_name}-master"
    }
}

output "master_ip" {
  value = "${aws_instance.master_node.private_ip}"
}
