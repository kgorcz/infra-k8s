locals {
    join_teleport = templatefile("scripts/join-teleport.sh", {
        bastion_ip = "${var.bastion_private_ip}"
    })
    setup_teleport_k8s = templatefile("scripts/setup-teleport-k8s.sh", {
        bastion_private_ip = "${var.bastion_private_ip}"
        bastion_public_ip = "${var.bastion_public_ip}"
    })
}
