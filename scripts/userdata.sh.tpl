MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
set -ex

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm || true
sudo yum -y localinstall amazon-ssm-agent.rpm || true
sudo systemctl enable amazon-ssm-agent || true
sudo systemctl start amazon-ssm-agent || true
rm -f amazon-ssm-agent.rpm || true

# Sysctl Kernel optimization changes
## Disable IPv6
cat <<EOF >/etc/sysctl.d/10-disable-ipv6.conf
# disable ipv6 config
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

## Kube network optimisation.
cat <<EOF >/etc/sysctl.d/99-kube-net.conf
# Have a larger connection range available
net.ipv4.ip_local_port_range=1024 65535

# The maximum number of "backlogged sockets".  Default is 128.
net.core.somaxconn=65535
net.core.netdev_max_backlog=65536

# 32MB per socket - which sounds like a lot,
# but will virtually never consume that much.
net.core.rmem_max=33554432
net.core.wmem_max=33554432

# Increase the maximum amount of option memory buffers
net.core.optmem_max=25165824

# Default Socket Receive Buffer
net.core.rmem_default=31457280

# Default Socket Send Buffer
net.core.wmem_default=31457280

# Various network tunables
# Increase the number of outstanding syn requests allowed.
net.ipv4.tcp_max_syn_backlog=20480
net.ipv4.tcp_max_tw_buckets=400000
net.ipv4.tcp_no_metrics_save=1

# Increase the maximum total buffer-space allocatable
# This is measured in units of pages (4096 bytes)
net.ipv4.tcp_mem=786432 1048576 26777216
net.ipv4.udp_mem=65536 131072 262144InstanceTypesOverride

# Increase the read-buffer space allocatable
net.ipv4.tcp_rmem=8192 87380 33554432
net.ipv4.udp_rmem_min=16384

# Increase the write-buffer-space allocatable
net.ipv4.tcp_wmem=8192 65536 33554432
net.ipv4.udp_wmem_min=16384

# Increase the tcp-time-wait buckets pool size to prevent simple DOS attacks
net.ipv4.tcp_max_tw_buckets=1440000
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15

net.ipv4.tcp_syn_retries=2
net.ipv4.tcp_synack_retries=2
#vm.min_free_kbytes=65536
# Protect Against TCP Time-Wait
net.ipv4.tcp_rfc1337=1
# Control Syncookies
net.ipv4.tcp_syncookies=1

# Connection tracking to prevent dropped connections (usually issue on LBs)
net.netfilter.nf_conntrack_max=262144
net.ipv4.netfilter.ip_conntrack_generic_timeout=120
net.netfilter.nf_conntrack_tcp_timeout_established=86400

# ARP cache settings for a highly loaded docker swarm
net.ipv4.neigh.default.gc_thresh1=8096
net.ipv4.neigh.default.gc_thresh2=12288
net.ipv4.neigh.default.gc_thresh3=16384

# Increase size of file handles and inode cache
fs.file-max=2097152

# Do less swapping
vm.swappiness=10
vm.dirty_ratio=60
vm.dirty_background_ratio=2

# Sets the time before the kernel considers migrating a proccess to another core
kernel.sched_migration_cost_ns=5000000
EOF

# Disable THP
cat <<EOF >/etc/rc.local
echo never > /sys/kernel/mm/transparent_hugepage/enabled
EOF

sudo sysctl --system
sudo sysctl -p
sudo systemctl daemon-reload
## End of kernel optimization

## Inject imageGCHighThresholdPercent value unless it has already been set.
## check docs --> https://aws.amazon.com/premiumsupport/knowledge-center/eks-worker-nodes-image-cache/

if ! grep -q imageGCHighThresholdPercent /etc/kubernetes/kubelet/kubelet-config.json;
then
    sed -i '/"apiVersion*/a \ \ "imageGCHighThresholdPercent": 70,' /etc/kubernetes/kubelet/kubelet-config.json
fi

# Inject imageGCLowThresholdPercent value unless it has already been set.
if ! grep -q imageGCLowThresholdPercent /etc/kubernetes/kubelet/kubelet-config.json;
then
    sed -i '/"imageGCHigh*/a \ \ "imageGCLowThresholdPercent": 50,' /etc/kubernetes/kubelet/kubelet-config.json
fi

## Initializing kubelet based on spot/ondemand
instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

export AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)

instance_type=$(curl --silent http://169.254.169.254/latest/meta-data/instance-life-cycle)

shopt -s nocasematch

if [[ "spot" =~ "$instance_type" ]]; then

  echo "**** Innitializing bootstrap configuration for ${instance_type} ****"
  echo ""

  /etc/eks/bootstrap.sh '${CLUSTER_NAME}' --b64-cluster-ca '${B64_CLUSTER_CA}' --apiserver-endpoint '${API_SERVER_URL}' --kubelet-extra-args "--system-reserved cpu=250m,memory=0.2Gi,ephemeral-storage=1Gi --kube-reserved cpu=250m,memory=1Gi,ephemeral-storage=1Gi --eviction-hard memory.available<0.2Gi,nodefs.available<10% --allowed-unsafe-sysctls net.core.somaxconn,net.ipv4.tcp_tw_reuse --event-qps=0 --read-only-port=0"

else

  echo "**** Innitializing bootstrap configuration for ${instance_type} ****"
  echo ""

  /etc/eks/bootstrap.sh '${CLUSTER_NAME}' --b64-cluster-ca '${B64_CLUSTER_CA}' --apiserver-endpoint '${API_SERVER_URL}' --kubelet-extra-args "--system-reserved cpu=250m,memory=0.2Gi,ephemeral-storage=1Gi --kube-reserved cpu=250m,memory=1Gi,ephemeral-storage=1Gi --eviction-hard memory.available<0.2Gi,nodefs.available<10% --allowed-unsafe-sysctls net.core.somaxconn,net.ipv4.tcp_tw_reuse --event-qps=0 --read-only-port=0"

fi

--==MYBOUNDARY==--