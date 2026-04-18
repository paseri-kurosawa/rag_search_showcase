#!/bin/bash

# EC2 停止スクリプト（何度も使用）
# 役割: EC2 インスタンス停止

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
echo "EC2 停止中..."
echo "=========================================="
echo "Instance ID: $INSTANCE_ID"
echo "Region: $REGION"

aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $REGION

echo "✅ EC2 停止リクエスト送信完了"
echo ""
echo "起動時:"
echo "  ./scripts/launch_ec2.sh"
echo ""
