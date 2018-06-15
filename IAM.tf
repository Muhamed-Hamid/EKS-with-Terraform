## Create roles and policies

resource "aws_iam_role" "eks-stage" {
    name = "eks-stage"
    path = "/"
    assume_role_policy = "${file("./policy/cluster_role.json")}"
}

resource "aws_iam_role_policy_attachment" "k8s-EKS-service" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
    role = "${aws_iam_role.eks-stage.name}"
}

resource "aws_iam_policy_attachment" "k8s-EKS" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    role = "${aws_iam_role.eks-stage.name}"
}

resource "aws_iam_role" "eks-nodes" {
  name = "eks-nodes"
  path = "/"
  assume_role_policy = "${file("./policy/nodes_role.json")}"
}

resource "aws_iam_role_policy_attachment" "eks-nodes" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.eks-nodes.name}"
}

resource "aws_iam_role_policy_attachment" "eks-nodes-CNI" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.eks-nodes.name}"
}

resource "aws_iam_role_policy_attachment" "eks-nodes-ECR" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.eks-nodes.name}"
}
#group for nodes  
resource "aws_iam_instance_profile" "eks-nodes-profile"{
  name = "eks-nodes-profile"
  role = "${aws_iam_role.eks-nodes-profile.name}"
}
resource "aws_security_group" "eks-nodes-group"{
  name = "eks-nodes-group"
  vpc_id = "${aws_vpc.vpc.id}"
  description = "group for all nodes"
  egress {
    from_port = 0
    to_port = 0
    cidr_block = "[0.0.0.0/0]"
    protocol = "-1"
  }
  tags {
    Name = "${var.env}-eks-nodes"
    Env = "${var.env}"
  }
}
resource "aws_security_group_rule" "inbound-con" {
  from_port = 1025
  to_port = 65535
  type = "ingress"
  security_group_id = "${aws_security_group.eks-nodes-group.id}"
  source_security_group_id = "${aws_security_group.eks-stage.id}"
  description = "Allow connection from CP"
  protocol = "tcp"
}
resource "aws_security_group" "nodes-con"{
  from_port = 0
  to_port = 65535
  type = "ingress"
  security_group_id = "${aws_security_group.eks-nodes-group.id}"
  source_security_group_id = "${aws_security_group.eks-nodes-group.id}"
  description = "Allow nodes connection"
  protocol = "-1"
}
