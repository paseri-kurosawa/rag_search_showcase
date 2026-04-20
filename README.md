# RAG Search Showcase

## 概要

**RAG Search Showcase** は、黒澤ぱせり（著述家・エンジニア）の記事・著作を対象とした **Retrieval-Augmented Generation (RAG)** の実装ショーケースです。

このプロジェクトは、OpenSearch と AWS Bedrock Claude AI を組み合わせて、自然言語での質問に対して、関連ドキュメントを検索し、AI が日本語で回答を生成するシステムです。

### 🎯 主な機能

- **ドキュメント検索**: OpenSearch を使用した高速なセマンティック検索
- **LLM 統合**: AWS Bedrock Claude Haiku 4.5 による日本語回答生成
- **モーダルビューアー**: 参考ドキュメントをクリックで全文表示

## ⚠️ このプロジェクトについて

**このプロジェクトはショーケース（概念実証）です。**

以下の点に注意してください：
- 本番環境での使用を想定していません
- セキュリティ対策は基本レベルです
- AWS リソースは継続的なコスト発生のため、不要時は停止してください

## 🚀 使用方法

### 前提条件

- AWS アカウント（ap-northeast-1 リージョン）
- AWS CLI の設定済み
- SSH キーペア（`~/.ssh/rag-key.pem`）
- Bash シェル環境

### EC2 サーバーの起動

```bash
cd /path/to/rag_search_showcase
./scripts/launch_ec2.sh
```

**実行内容：**
- EC2 インスタンスを起動
- 起動完了待機
- Public IP を表示

**出力例：**
```
✅ EC2 起動完了
Public IP: 54.250.32.49

確認コマンド:
  ssh -i ~/.ssh/rag-key.pem ec2-user@54.250.32.49
  curl -s http://54.250.32.49:9200
```

起動後、ブラウザで以下にアクセス：
```
http://<Public IP>/
```

### EC2 サーバーの停止

```bash
./scripts/stop_ec2.sh
```

**実行内容：**
- EC2 インスタンスを停止
- コスト削減（停止中の費用は ~$1-2/月）

⚠️ **注意**: サーバーを停止してもデータは保持されます。再起動時は同じデータが利用可能です。

### SSH 接続（トラブルシューティング用）

```bash
ssh -i ~/.ssh/rag-key.pem ec2-user@<Public IP>
```

## 🏗️ システムアーキテクチャ

```
ユーザー入力
    ↓
ブラウザ（Vue.js + 日本語UI）
    ↓
Laravel API (/api/search, /api/document-detail)
    ↓
┌─────────────────────────────────────┐
│  OpenSearch (ドキュメント検索)        │
│  - 5件の関連ドキュメント取得          │
│  - セマンティック検索対応            │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  AWS Bedrock (LLM)                  │
│  - Claude Haiku 4.5                 │
│  - Inference Profile: 日本向け       │
│  - 日本語での回答生成                 │
└─────────────────────────────────────┘
    ↓
ブラウザに表示（回答 + 参考ドキュメント）
```

## 📁 プロジェクト構造

```
rag_search_showcase/
├── app/
│   └── Http/Controllers/Api/
│       └── RagController.php          # RAG ロジック（検索・LLM呼び出し）
├── resources/
│   └── views/
│       └── welcome.blade.php          # フロントエンド UI
├── config/
│   └── aws_resources.json             # AWS リソース設定
├── scripts/
│   ├── launch_ec2.sh                  # EC2 起動スクリプト
│   ├── stop_ec2.sh                    # EC2 停止スクリプト
│   ├── setup_aws_infra.sh             # AWS インフラ初期化
│   └── setup_ec2_software.sh          # EC2 ソフトウェアセットアップ
├── documents/                         # 黒澤ぱせり著作物（Markdown）
└── README.md                          # このファイル
```

## 🛠️ 技術スタック

| コンポーネント | 技術 |
|---|---|
| **フロントエンド** | Blade Template + Vanilla JavaScript |
| **バックエンド** | Laravel 11 + PHP 8.2 |
| **検索エンジン** | OpenSearch 2.x |
| **LLM** | AWS Bedrock Claude Haiku 4.5 |
| **インフラ** | AWS EC2 (Amazon Linux 2023) |
| **ウェブサーバー** | Apache 2.4 + PHP-FPM |
| **認証** | AWS IAM Role (EC2) |
| **API通信** | AWS Signature v4 (HTTP署名) |

## 💰 コスト概算

| 状態 | 月額概算 |
|---|---|
| 停止時 | $1-2 |
| 起動時（24時間） | $60-80 |
| 起動時（1時間） | $2-3 |

⚠️ OpenSearch（t3.small インスタンス）と EC2（t3.small）のコストが主。

## 🔐 セキュリティに関する注記

このショーケースは学習・デモンストレーション目的です。本番環境での使用前に以下を検討してください：

- WAF (Web Application Firewall) の導入
- API 認証の強化（現在は基本的なレベル）
- HTTPS 化（SSL/TLS 証明書）
- ログ監視と通知設定
- 定期的なセキュリティ監査

## 📝 ドキュメント（黒澤ぱせりの著作物）

`documents/` ディレクトリに Markdown 形式で保存されています。

### ドキュメント形式

```markdown
---
title: "タイトル"
category: "カテゴリ"
source: "出典"
---

# 本文
...
```

新しいドキュメントを追加する場合は、同じ形式で `documents/` に配置し、API の `/api/ingest` を実行してください。

## 🚀 トラブルシューティング

### EC2 が起動しない

```bash
aws ec2 describe-instances --instance-ids i-029550d7da45ff22c --region ap-northeast-1
```

### OpenSearch が応答しない

```bash
ssh -i ~/.ssh/rag-key.pem ec2-user@<IP>
sudo systemctl status opensearch
```

### ブラウザでアクセスできない

```bash
# ウェブサーバーの状態確認
ssh -i ~/.ssh/rag-key.pem ec2-user@<IP>
sudo systemctl status httpd
```

## 📚 参考情報

- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [OpenSearch Project](https://opensearch.org/)
- [Laravel Documentation](https://laravel.com/docs)

## 📄 ライセンス

このプロジェクトのコードは MIT ライセンス下で公開されています。

ただし、`documents/` に含まれる黒澤ぱせりの著作物は、著者の著作権下にあります。

---

**最終更新**: 2026-04-20  
**バージョン**: v5 (Modal Document Viewer)  
**AMI ID**: `ami-025407d45eeb2096e`
