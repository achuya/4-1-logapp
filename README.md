# 4-1-logapp

CloudWatch ログ・アラートを使ったFastAPI on ECS

---

## 目的

では~/dev/4-1-logapp/README.mdをVS Codeで開いて以下の内容を貼り付けてください：
markdown# 4-1-logapp

CloudWatch ログ・アラートを使ったFastAPI on ECS

---

## 目的
ログの大切さを知る
ログがない場合
└─ アプリが壊れても原因がわからない
└─ どのユーザーがいつアクセスしたかわからない
└─ 問題が起きてから気づくのが遅れる
ログがある場合
└─ エラーの原因がすぐわかる
└─ 不正アクセスを検知できる
└─ パフォーマンスの問題を早期発見できる


---

## 構成図

インターネット
↓
CloudFront（HTTPS・CDN）
↓
ALB（ロードバランサー）
↓
ECS Fargate（FastAPI）
↓
RDS MySQL（データベース）
ログ・監視
ECS → CloudWatch Logs → CloudWatch Insights（ログ検索）
→ CloudWatch Alarms → SNS → Lambda → Slack

---

## 使用技術

### アプリケーション
| 技術 | 用途 |
|------|------|
| Python + FastAPI | REST APIサーバー |
| SQLAlchemy | DBの操作（ORM） |
| python-json-logger | JSON形式のログ出力 |

### AWS インフラ
| サービス | 役割 |
|---------|------|
| ECS Fargate | コンテナの実行環境 |
| RDS MySQL | データベース |
| ALB | ロードバランサー |
| CloudFront | CDN・HTTPS化 |
| ECR | Dockerイメージの保存 |
| CloudWatch Logs | ログの収集・保存 |
| CloudWatch Insights | ログの検索・分析 |
| CloudWatch Alarms | 異常検知・アラート |
| SNS | 通知の中継 |
| Lambda | Slack通知処理 |
| Secrets Manager | パスワードの安全な管理 |
| SSM | 踏み台サーバーへの安全なアクセス |

### ツール
| ツール | 用途 |
|--------|------|
| Terraform | インフラのコード管理（IaC） |
| Docker | アプリのコンテナ化 |
| GitHub Actions | 自動デプロイ（CI/CD） |

---

## ファイル構成

4-1-logapp/
├── backend/
│   ├── app/
│   │   ├── main.py          → アプリの入口・ログ設定・ミドルウェア
│   │   ├── database.py      → DB接続設定
│   │   ├── models.py        → DBテーブル定義
│   │   ├── schemas.py       → APIの入出力・バリデーション
│   │   └── routers/
│   │       └── items.py     → 商品APIエンドポイント
│   ├── Dockerfile
│   └── requirements.txt
└── infra/
├── main.tf              → 全モジュールを組み合わせる
├── variables.tf         → 変数の定義
├── outputs.tf           → 出力値の定義
├── terraform.tfvars     → 変数の値（gitignore済み）
└── modules/
├── network/         → VPC・サブネット・IGW・NAT
├── security/        → セキュリティグループ
├── rds/             → データベース
├── ecr/             → Dockerイメージの置き場
├── ecs/             → コンテナの実行環境・踏み台
├── alb/             → ロードバランサー
├── cloudfront/      → CDN
└── cloudwatch/      → ログ・アラート・Slack通知

---

## CloudWatchについて

### CloudWatch Logsとは？

AWSのログ管理サービス
仕組み
└─ アプリのログをCloudWatchに送信
└─ 30日間保存（設定による）
なぜJSON形式なのか？
通常のログ
"2024-01-01 ERROR Item not found"
→ 検索しにくい
JSON形式のログ
{"levelname": "ERROR", "message": "Item not found", "path": "/api/items/999"}
→ levelname・pathで絞り込みできる！

### CloudWatch Insightsとは？

ログをSQLのような言語で検索・分析するサービス
よく使うクエリ例
エラーログだけ取り出す
fields @timestamp, levelname, message, path
| filter levelname = "ERROR"
| sort @timestamp desc
| limit 20
404エラーだけ取り出す
fields @timestamp, message, path, status_code
| filter status_code = 404
| sort @timestamp desc
| limit 20
レスポンスが遅いリクエストを取り出す
fields @timestamp, method, path, duration_ms
| filter ispresent(duration_ms)
| sort duration_ms desc
| limit 10

### CloudWatch Alarmsとは？

メトリクスが条件を満たしたら通知するサービス
今回の設定
├─ CPU使用率が5%以上 → ALARMをSlackに通知
└─ 正常に戻ったとき → OKをSlackに通知
通知の流れ
CloudWatch Alarms
↓
SNS（Simple Notification Service）
↓
Lambda（Slack通知処理）
↓
Slack

---

## エラー設計

400 Bad Request（バリデーションエラー）
└─ 商品名が空の場合
└─ 商品名が255文字を超える場合
└─ 価格が負の値の場合
404 Not Found
└─ 存在しないIDを指定した場合
500 Internal Server Error
└─ DBへの接続に失敗した場合
└─ 予期しないエラーが発生した場合
なぜこのエラー設計なのか？
└─ ECサイトで実際に起こりうるエラーを想定
└─ CloudWatch Insightsで
どのエラーが多いか分析できる
└─ 適切なHTTPステータスコードを返すことで
フロントエンドが適切に処理できる

---

## ログ設計

```python
# リクエストログ（全リクエスト）
logger.info("リクエスト開始", extra={
    "method": "POST",
    "path": "/api/items/",
    "client": "192.168.1.1"
})

# 正常処理ログ
logger.info("商品を作成しました", extra={"item_id": 1})

# 警告ログ（404など）
logger.warning("商品が見つかりません", extra={"item_id": 999})

# エラーログ（500など）
logger.error("商品の作成に失敗しました", extra={"error": "..."})
```

---

## 環境の構築手順

### Step1: terraform.tfvarsを作成

```bash
cat > infra/terraform.tfvars << 'EOF'
aws_region           = "ap-northeast-1"
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
db_subnet_cidrs      = ["10.0.5.0/24", "10.0.6.0/24"]
db_name              = "logappdb"
db_username          = "admin"
db_password          = "Password1234!"
task_cpu             = 256
task_memory          = 512
slack_webhook_url    = "あなたのSlack Webhook URL"
EOF
```

### Step2: インフラを構築

```bash
cd infra
terraform init
terraform apply
```

> ⚠️ RDS・CloudFrontの作成に20〜30分かかります

### Step3: ECRにDockerイメージをpush

```bash
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin \
  ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com

docker buildx build \
  --platform linux/amd64 \
  -t ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com/logapp-backend:latest \
  --push \
  ./backend
```

### Step4: ECSサービスを更新

```bash
aws ecs update-service \
  --cluster logapp-cluster \
  --service logapp-backend-service \
  --force-new-deployment \
  --region ap-northeast-1
```

### Step5: RDSにmigration

```bash
# 踏み台サーバーのIDを確認
terraform -chdir=infra output bastion_instance_id

# SSM経由で接続
aws ssm start-session \
  --target <bastion_instance_id> \
  --region ap-northeast-1
```

踏み台サーバー内で：

```bash
sudo yum install -y python3 python3-pip
pip3 install sqlalchemy pymysql cryptography

python3 << 'EOF'
from sqlalchemy import create_engine, Column, Integer, String, Text, DateTime
from sqlalchemy.orm import declarative_base
from sqlalchemy.sql import func

DATABASE_URL = "mysql+pymysql://admin:PASSWORD@RDS_ENDPOINT:3306/logappdb"
engine = create_engine(DATABASE_URL)
Base = declarative_base()

class Item(Base):
    __tablename__ = "items"
    id = Column(Integer, primary_key=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    price = Column(Integer, nullable=False)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now())

Base.metadata.create_all(bind=engine)
print("Migration completed!")
EOF
```

### Step6: 動作確認

```bash
# ヘルスチェック
curl https://<CloudFrontURL>/health

# 商品作成
curl -X POST https://<CloudFrontURL>/api/items/ \
  -H "Content-Type: application/json" \
  -d '{"name": "テスト商品", "description": "説明", "price": 1000}'

# 404エラー発生
curl https://<CloudFrontURL>/api/items/999

# CloudWatch Insightsでログを確認
# AWSコンソール → CloudWatch → ログのインサイト → /ecs/logapp-backend
```

---

## CloudWatch Insightsの使い方

AWSコンソール → CloudWatch → ログのインサイト
ロググループで /ecs/logapp-backend を選択
クエリを入力して実行

よく使うクエリ
エラーログのみ
fields @timestamp, levelname, message
| filter levelname = "ERROR"
| sort @timestamp desc
404エラーのみ
fields @timestamp, message, path, status_code
| filter status_code = 404
| sort @timestamp desc
CPU負荷テスト（大量リクエスト送信）
for i in $(seq 1 100); do
curl -s http://<ALB_URL>/api/items/ > /dev/null &
done
wait


---

## GitHub ActionsのCI/CD設定

Settings → Secrets and variables → Actions
AWS_ACCESS_KEY_ID     → AWSのアクセスキーID
AWS_SECRET_ACCESS_KEY → AWSのシークレットアクセスキー

自動デプロイの流れ：

backend/フォルダを変更してpush
↓
deploy-backend.ymlが起動
↓
Dockerビルド → ECR push → ECSデプロイ

---

## 環境の削除手順

```bash
cd infra
terraform destroy
```

> ⚠️ NAT Gatewayは課金が続くので使い終わったら必ずdestroyしましょう！

