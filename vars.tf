variable "sub-1a-priv" {
    type = "map"
    default {
        cidr_block = "192.168.20.0/21"
    }
}
variable "sub-1b-priv" {
    type = "map"
    default {
        cidr_block = "192.168.21.0/21"
    }
}
variable "vpc" {
    default = "192.168.0.0/16"
}
variable "cluster-name" {
    default = "EKS-staging"
    type = "string"
}
variable "region" {
    default = "us-east-1"
    description = "Region"
}
variable "ami" {
    default = "ami-dea4d5a1"
}
variable "key" {
    default = "Morsi-Key"
    description = "Default"
}
variable "env" {
    default = "staging"
}