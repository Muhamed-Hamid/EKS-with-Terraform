resource "aws_security_group" "stage-cluster" {
    name = "eks-stage"
    description = "connection to minion nodes"
    vpc_id = "${aws_vpc.vpc.id}"
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_block = ["0.0.0.0/0"]
    }
    tags {
        Name = "${var.env}-cluster"
        Maintainer = "Muhamed"

    }
}
resource "aws_security_group_rule" "fleet-API-connection" {
    description = "Allow internal communications to API gateway"
    type = "ingress"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    security_group_id = "${aws_security_group.stage-cluster.id}"
    source_security_group_id = "${aws_security_group.nodes.id}"
}
resource "aws_security_group_rule" "fleet-ext-conns" {
    description = "Allow company's CIDR connection to API"
    type = "ingress"
    from_port = 0
    to_port = 65535
    cidr_block = ["192.168.10.100/24"]
    protocol = "tcp"
    security_group_id = "${aws_security_group.stage-cluster.id}"
}
resource "aws_eks_cluster" "stage-cluster"{
    name = "${var.cluster-name}"
    role_arn = "${aws_iam_role.eks-stage}"
    vpc_config {
        security_group_ids = ["${aws_security_group.stage-cluster.id}"]
        subnet_ids = [
            "${aws_subnet.sub-1a-priv.*.id}",
            "${aws_subnet.sub-1b-priv.*.id}",
        ]
    }
    depends_on = [
        "${aws_iam_role_policy_attachment.k8s-EKS}",
        "${aws_iam_role_policy_attachment.k8s-EKS-service}",
    ]
}