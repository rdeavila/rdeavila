#!/bin/env bash
# curl -sSL https://raw.githubusercontent.com/rdeavila/rdeavila/main/scripts/k8s-install.sh | bash

# Firewall
sudo systemctl stop firewalld
sudo systemctl disable firewalld

#SELinux
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

#Kernel
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
overlay
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Network
cat <<EOF | sudo tee /etc/NetworkManager/conf.d/calico.conf
[keyfile]
unmanaged-devices=interface-name:cali*;interface-name:tunl*;interface-name:vxlan.calico;interface-name:vxlan-v6.calico;interface-name:wireguard.cali;interface-name:wg-v6.cali
EOF

# Dependencies
sudo yum install yum-utils vim wget nmap-ncat epel-release jq -y
sudo yum update -y

# sysctl
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# Docker
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce docker-ce-cli containerd.io -y

sudo mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "bip": "172.26.0.1/16"
}
EOF

sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl restart docker

# Containerd
sudo containerd config default > /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl enable containerd
sudo systemctl restart containerd

# Kubernetes
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet

# Manual commands
echo ""
echo "Run this command to start the controlplane"
echo "   kubeadm config images pull"
echo "   kubeadm init --control-plane-endpoint 192.168.1.149 --pod-network-cidr=172.26.0.1/16"
echo "   kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml"
echo ""

exit 0