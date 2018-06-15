#Resources and launch group
provider "aws" {
    shared_credentials_file = "./.aws/credentials"
    profile = "staging"
    region = "${var.region}"
}

data "aws_region" "current"{}
data "aws_availability_zones" "available" {}

# Joining mama's big cluster

locals {
    config-map-aws-auth = <<CONFIGMAPAWSAUTH

apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.eks-stage.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH

    kubeconfig = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.eks-cluster.endpoint}
    certificate-authority-data: ${aws_eks_cluster.eks-stage.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: heptio-authenticator-aws
      args:
        - "token"
        - "-i"
        - "${var.cluster-name}"
KUBECONFIG

  eks-nodes-userdata = <<USERDATA
#!/bin/bash -xe
CA_CERTIFICATE_DIRECTORY=/etc/kubernetes/pki
CA_CERTIFICATE_FILE_PATH=$CA_CERTIFICATE_DIRECTORY/ca.crt
mkdir -p $CA_CERTIFICATE_DIRECTORY
echo "${aws_eks_cluster.eks-cluster.certificate_authority.0.data}" | base64 -d >  $CA_CERTIFICATE_FILE_PATH
INTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
sed -i s,MASTER_ENDPOINT,${aws_eks_cluster.eks-cluster.endpoint},g /var/lib/kubelet/kubeconfig
sed -i s,CLUSTER_NAME,${var.cluster-name},g /var/lib/kubelet/kubeconfig
sed -i s,REGION,${data.aws_region.current.name},g /etc/systemd/system/kubelet.service
sed -i s,MAX_PODS,20,g /etc/systemd/system/kubelet.service
sed -i s,MASTER_ENDPOINT,${aws_eks_cluster.eks-cluster.endpoint},g /etc/systemd/system/kubelet.service
sed -i s,INTERNAL_IP,$INTERNAL_IP,g /etc/systemd/system/kubelet.service
DNS_CLUSTER_IP=192.168.0.10
if [[ $INTERNAL_IP == 192.* ]] ; then DNS_CLUSTER_IP=192.168.20.10; fi
sed -i s,DNS_CLUSTER_IP,$DNS_CLUSTER_IP,g /etc/systemd/system/kubelet.service
sed -i s,CERTIFICATE_AUTHORITY_FILE,$CA_CERTIFICATE_FILE_PATH,g /var/lib/kubelet/kubeconfig
sed -i s,CLIENT_CA_FILE,$CA_CERTIFICATE_FILE_PATH,g  /etc/systemd/system/kubelet.service
systemctl daemon-reload
systemctl restart kubelet kube-proxy
USERDATA
}
output "confi-map-aws-auth"{
    value = "${local.config-map-aws-auth}"
}
output "kubeconfig" {
    value = "${local.kubeconfig}"
}
## max of t2.large is 35 Pods
resource "aws_launch_configuration" "resources"{
    associate_public_ip_address = true
    iam_instance_profile = "${aws_instance_profile.eks-nodes-profile.name}"
    image_id = "${var.ami"}"
    instance_type = "t2.large"
    name_prefix = "eks-fleet-resouces"
    user_data_base64 = "${base64encode(local.eks-nodes-userdata)}"
    lifecycle {
        create_before_destroy = true
    }
}
resource "aws_autoscaling_group" "autoscaling-group" {
    desired_capacity     = 2
    launch_configuration = "${aws_launch_configuration.resources.id}"
    max_size             = 2
    min_size             = 1
    name                 = "eks-autoscaling-group"
    vpc_zone_identifier = [
        "${aws_subnet.sub-1a-priv.*.id}",
        "${aws_subnet.sub-1b-priv.*.id}",
    ]
    tag {
        key = "Name"
        value = "eks-autoscaling-group"
        propagate_at_launch = true
    }
    tag {
        key = "kubernetes.io/cluster/${var.cluster-name}"
        value = "owned"
        propagate_at_launch = true
    }
