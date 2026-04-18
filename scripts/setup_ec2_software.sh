#!/bin/bash

set -e

# EC2 内部での OpenSearch/PHP/Composer セットアップ
# 実行場所: EC2 内で実行 (`ssh ... 'bash -s' < setup_ec2_software.sh`)
# 役割: OpenSearch, PHP 8.3, Composer をインストール・起動

echo "=========================================="
echo "EC2 ソフトウェアセットアップ開始"
echo "=========================================="

# ===== 1. システム更新 =====
echo "[1/6] システム更新中..."
sudo yum update -y

# ===== 2. Java インストール（OpenSearch 用）=====
echo "[2/6] Java インストール中..."
sudo yum install -y java-17-amazon-corretto-devel

java -version

# ===== 3. OpenSearch インストール =====
echo "[3/6] OpenSearch インストール中..."
cd /opt

# OpenSearch 2.11 をダウンロード
sudo wget https://artifacts.opensearch.org/releases/bundle/opensearch/2.11.1/opensearch-2.11.1-linux-x64.tar.gz

sudo tar -xzf opensearch-2.11.1-linux-x64.tar.gz
sudo rm opensearch-2.11.1-linux-x64.tar.gz
sudo mv opensearch-2.11.1 opensearch

# opensearch ユーザー作成
sudo useradd -r opensearch || true

# ディレクトリ権限設定
sudo chown -R opensearch:opensearch /opt/opensearch

# OpenSearch 設定
sudo tee /opt/opensearch/config/opensearch.yml > /dev/null <<'YAML'
cluster.name: rag-showcase
node.name: rag-node-1
network.host: 0.0.0.0
http.port: 9200
discovery.seed_hosts: []
cluster.initial_cluster_manager_nodes: ["rag-node-1"]
plugins.security.disabled: true
YAML

# OpenSearch 起動（systemd サービス化）
sudo tee /etc/systemd/system/opensearch.service > /dev/null <<'SERVICE'
[Unit]
Description=OpenSearch
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=opensearch
Group=opensearch
ExecStart=/opt/opensearch/bin/opensearch
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable opensearch
sudo systemctl start opensearch

echo "OpenSearch 起動中..."
sleep 10

# ===== 4. OpenSearch 起動確認 =====
echo "[4/6] OpenSearch 起動確認中..."
for i in {1..30}; do
  if curl -s http://localhost:9200 > /dev/null 2>&1; then
    echo "✅ OpenSearch 起動確認"
    curl -s http://localhost:9200 | grep -q "cluster_name" && echo "✅ クラスタ情報確認"
    break
  fi
  echo "試行 $i/30..."
  sleep 2
done

# ===== 5. PHP 8.3 インストール =====
echo "[5/6] PHP 8.3 インストール中..."
sudo amazon-linux-extras install -y php8.3
sudo yum install -y php8.3-{cli,common,curl,json,xml,zip,gd,pdo,mbstring}

php --version

# ===== 6. Composer インストール =====
echo "[6/6] Composer インストール中..."
cd /tmp
curl -sS https://getcomposer.org/installer -o composer-setup.php
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php

composer --version

# ===== セットアップ完了 =====
echo ""
echo "=========================================="
echo "✅ EC2 セットアップ完了"
echo "=========================================="
echo ""
echo "確認コマンド:"
echo "  curl http://localhost:9200"
echo "  php --version"
echo "  composer --version"
echo ""
