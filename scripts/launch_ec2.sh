#!/bin/bash

# EC2 起動スクリプト（何度も使用）
# 役割: EC2 インスタンス起動

set -e

CONFIG_FILE="config/aws_resources.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ エラー: $CONFIG_FILE が見つかりません"
  echo "先に setup_aws_infra.sh を実行してください"
  exit 1
fi

INSTANCE_ID=$(jq -r '.instance_id' "$CONFIG_FILE")
REGION=$(jq -r '.region' "$CONFIG_FILE")

echo "=========================================="
echo "EC2 起動中..."
echo "=========================================="
echo "Instance ID: $INSTANCE_ID"
echo "Region: $REGION"

aws ec2 start-instances --instance-ids $INSTANCE_ID --region $REGION

echo "起動完了待機中..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

# Public IP 更新
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region $REGION \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "✅ EC2 起動完了"
echo "Public IP: $PUBLIC_IP"
echo ""
echo "確認コマンド:"
echo "  ssh -i ~/.ssh/rag-key.pem ec2-user@$PUBLIC_IP"
echo "  curl -s http://$PUBLIC_IP:9200"
echo ""
