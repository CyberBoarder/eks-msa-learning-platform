#!/bin/bash

# EKS Node Group User Data Script
# 노드 초기화 및 클러스터 조인을 위한 스크립트

set -o xtrace

# EKS 부트스트랩 스크립트 실행
/etc/eks/bootstrap.sh ${cluster_name} ${bootstrap_arguments}

# CloudWatch Agent 설치 및 구성
yum update -y
yum install -y amazon-cloudwatch-agent

# CloudWatch Agent 설정 파일 생성
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "/aws/eks/${cluster_name}/node/system",
                        "log_stream_name": "{instance_id}/messages"
                    },
                    {
                        "file_path": "/var/log/dmesg",
                        "log_group_name": "/aws/eks/${cluster_name}/node/system",
                        "log_stream_name": "{instance_id}/dmesg"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "EKS/Node",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60,
                "totalcpu": false
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            },
            "netstat": {
                "measurement": [
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 60
            },
            "swap": {
                "measurement": [
                    "swap_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# CloudWatch Agent 시작
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# 시스템 최적화
echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
sysctl -p

# Docker 로그 로테이션 설정
cat > /etc/docker/daemon.json << EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOF

# containerd 설정 최적화
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# 서비스 재시작
systemctl restart containerd
systemctl restart docker

# 노드 라벨링을 위한 스크립트 (선택사항)
cat > /usr/local/bin/label-node.sh << 'EOF'
#!/bin/bash
# 노드가 Ready 상태가 될 때까지 대기
while ! kubectl get nodes $(hostname -f) &>/dev/null; do
    sleep 10
done

# 추가 라벨 적용 (필요시)
# kubectl label nodes $(hostname -f) node-type=worker
EOF

chmod +x /usr/local/bin/label-node.sh

# 부팅 완료 로그
echo "EKS node initialization completed at $(date)" >> /var/log/eks-node-init.log