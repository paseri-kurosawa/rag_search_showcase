#!/bin/bash

set -e

# AWS インフラ自動セットアップ（Phase 2-1 ～ 2-2）
# 実行: ./scripts/setup_aws_infra.sh
# 役割: VPC/SecurityGroup/IAM Role/EC2 を一度だけ作成
# 出力: config/aws_resources.json（リソースID記録）

REGION="ap-northeast-1"
PROJECT_NAME="rag-showcase"
CONFIG_DIR="config"
CONFIG_FILE="$CONFIG_DIR/aws_resources.json"

echo "=========================================="
echo "AWS インフラセットアップ開始"
echo "=========================================="
echo "リージョン: $REGION"
echo "プロジェクト名: $PROJECT_NAME"
echo ""

# config/ ディレクトリ作成
mkdir -p "$CONFIG_DIR"

# ===== 1. VPC 作成 =====
echo "[1/7] VPC 作成中..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$PROJECT_NAME-vpc}]" \
  --region $REGION \
  --query 'Vpc.VpcId' \
  --output text)
echo "VPC ID: $VPC_ID"

# DNS 有効化
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames \
  --region $REGION

# ===== 2. Subnet 作成 =====
echo "[2/7] Subnet 作成中..."
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ${REGION}a \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$PROJECT_NAME-subnet}]" \
  --region $REGION \
  --query 'Subnet.SubnetId' \
  --output text)
echo "Subnet ID: $SUBNET_ID"

# パブリック IP 自動割り当て有効化
aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET_ID \
  --map-public-ip-on-launch \
  --region $REGION

# ===== 3. Internet Gateway 作成・アタッチ =====
echo "[3/7] Internet Gateway 作成中..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$PROJECT_NAME-igw}]" \
  --region $REGION \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)
echo "IGW ID: $IGW_ID"

aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID \
  --region $REGION

# ===== 4. Route Table 作成・設定 =====
echo "[4/7] Route Table 設定中..."
RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$PROJECT_NAME-rt}]" \
  --region $REGION \
  --query 'RouteTable.RouteTableId' \
  --output text)
echo "Route Table ID: $RT_ID"

aws ec2 create-route \
  --route-table-id $RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID \
  --region $REGION

aws ec2 associate-route-table \
  --subnet-id $SUBNET_ID \
  --route-table-id $RT_ID \
  --region $REGION

# ===== 5. Security Group 作成 =====
echo "[5/7] Security Group 作成中..."
SG_ID=$(aws ec2 create-security-group \
  --group-name $PROJECT_NAME-sg \
  --description "RAG Showcase Security Group" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)
echo "Security Group ID: $SG_ID"

# SSH (22)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 22 \
  --cidr 0.0.0.0/0 \
  --region $REGION

# HTTP (80)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 80 \
  --cidr 0.0.0.0/0 \
  --region $REGION

# HTTPS (443)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 443 \
  --cidr 0.0.0.0/0 \
  --region $REGION

echo "Security Group ルール設定完了: SSH/HTTP/HTTPS"

# ===== 6. IAM Role 作成 =====
echo "[6/7] IAM Role 作成中..."

# Trust Policy JSON 作成
cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

IAM_ROLE_NAME="$PROJECT_NAME-role"
aws iam create-role \
  --role-name $IAM_ROLE_NAME \
  --assume-role-policy-document file:///tmp/trust-policy.json || true

# Bedrock 権限追加
aws iam attach-role-policy \
  --role-name $IAM_ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonBedrockFullAccess || true

# Instance Profile 作成
aws iam create-instance-profile \
  --instance-profile-name $PROJECT_NAME-profile || true

# Role を Profile に紐付け
aws iam add-role-to-instance-profile \
  --instance-profile-name $PROJECT_NAME-profile \
  --role-name $IAM_ROLE_NAME || true

echo "IAM Role: $IAM_ROLE_NAME"
sleep 5  # IAM 反映待ち

# ===== 7. EC2 起動 =====
echo "[7/7] EC2 t3.small 起動中..."

# 最新の Amazon Linux 2023 AMI を取得
AMAZON_LINUX_AMI=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-*" "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text \
  --region $REGION)

echo "使用AMI: $AMAZON_LINUX_AMI"

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMAZON_LINUX_AMI \
  --instance-type t3.small \
  --key-name $(aws ec2 describe-key-pairs --region $REGION --query 'KeyPairs[0].KeyName' --output text) \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --iam-instance-profile Name=$PROJECT_NAME-profile \
  --block-device-mappings "DeviceName=/dev/xvda,Ebs={VolumeSize=30,VolumeType=gp3}" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$PROJECT_NAME-ec2}]" \
  --region $REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instance ID: $INSTANCE_ID"

# 起動完了待ち
echo "EC2 起動待機中..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

# Public IP 取得
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region $REGION \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "Public IP: $PUBLIC_IP"

# ===== リソース情報を JSON に記録 =====
echo ""
echo "=========================================="
echo "リソース情報を記録中..."
echo "=========================================="

cat > "$CONFIG_FILE" <<EOF
{
  "region": "$REGION",
  "vpc_id": "$VPC_ID",
  "subnet_id": "$SUBNET_ID",
  "internet_gateway_id": "$IGW_ID",
  "route_table_id": "$RT_ID",
  "security_group_id": "$SG_ID",
  "iam_role_name": "$IAM_ROLE_NAME",
  "instance_id": "$INSTANCE_ID",
  "public_ip": "$PUBLIC_IP",
  "ami_id": "$AMAZON_LINUX_AMI",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "✅ 設定ファイル: $CONFIG_FILE"
echo ""
echo "=========================================="
echo "セットアップ完了"
echo "=========================================="
echo ""
echo "📌 次のステップ:"
echo "1. SSH ログイン確認:"
echo "   ssh -i ~/.ssh/your-key-pair.pem ec2-user@$PUBLIC_IP"
echo ""
echo "2. Phase 2-3: OpenSearch インストール"
echo ""

cat "$CONFIG_FILE"
