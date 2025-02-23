# プロジェクト名: iac-dev-project


## 概要:
このプロジェクトは、AWS上に簡単なインフラストラクチャを構築するためのTerraform設定、
ansibleを使用したwebサーバー構築の設定を含んでいます。


## 使用技術:
- Terraform（v1.10.5）
- Ansible（core 2.15.3）
- AWS
- Linux(Amazon Linux 2023)


## インストールと使用方法:

### terraformの設定:
1. Terraformをインストールします。
2. このリポジトリをクローンまたはダウンロードします。
3. `terraform init` コマンドを実行してプロバイダーのプラグインをダウンロードします。
4. `terraform plan -var-file vars.tfvars ` コマンドを実行してプランを確認します。
5. `terraform apply -var-file vars.tfvars` コマンドを実行してインフラストラクチャをデプロイします。

### Ansibleの設定:
1. inventoryファイルを作成します。
2. ansible masterにsshでログインをします。
3. 下記コマンドでansibleをinstallします。
`sudo yum install ansible -y`
`ansible --version`

4. ssh接続のための準備のため下記設定を行います
事前に準備していた秘密鍵を使用して、ansible masterにログインします（ユーザー名: ec2-user）
`vim iac-dev-key.pem`で自身の秘密鍵をansible masterに格納します。
`chmod 600 iac-dev-key.pem`
`eval $(ssh-agent -s)`
`sudo cp -p iac-dev-key.pem ~/.ssh/iac-dev-key.pem`
`ssh-add ~/.ssh/iac-dev-key.pem`
`ssh-add -l`

5. inventroy.txtとplaybook.yamlを張り付ける
`vim inventroy.txt`
`vim playbook.yaml`

6. webserversとの疎通確認
`ansible iac-dev-ec2-web1 -i inventroy.txt -m ping`  yes
`ansible iac-dev-ec2-web2 -i inventroy.txt -m ping`  yes
`ansible webservers -i inventroy.txt -m ping`

7. playbookの実行
`ansible-playbook playbook.yaml -i inventroy.txt -v`

8. service確認
ブラウザ上で下記URLにアクセス
http://[web1-server-IPアドレス]  "This is web1"が表示されることを確認
http://[web1-server-IPアドレス]  "This is web2"が表示されることを確認
http://[ALBのDNS名]              更新ボタンを押して"This is web1" "This is web2"どちらも表示され、負荷分散できていることを確認


## 変数:
- `iac-dev-access-key`: AWSのアクセスキー
- `iac-dev-secret-key`: AWSのシークレットキー


## ファイル構成:
- `main.tf`        : メインのTerraform設定ファイル
- `vars.tfvars`    : アクセスキー、シークレットキーを管理するファイル。（個人情報のためサンプルの雛形だけを定義）
- `playbook.yaml`  : webサーバー構築用のメインとなるAnsible設定ファイル
- `inventory.txt`  : webサーバーのIPアドレス、接続方法、接続ユーザを定義
- `iac-dev-key.pem`: 事前にaws上でキーペアを作成して、ダウンロードする必要があります。
                     EC2インスタンスの作成に使用しているので鍵名も同一で作成すること


## 注意点:
- `main.tf`と`vars.tfvars`は同じディレクトリに保存してください
- ssh-agentのは、tera termなどのターミナルソフトから一度接続を終了すると再度実行する必要があります。
- 最小スペック構成のため、albのdns名を指定して接続する場合、時間がかかりタイムアウトのエラーが発生する可能性があります。
- ssl証明書を使用していないので、すべて"http"での接続になることに注意してください
- アクセスキーや秘密鍵はなくさないように大切に保管してください


## 工夫した点と改善点:
- 今回は、簡単な構成ではあるがより実務に近い環境を設計することを意識しています。

- aws用のプラグインにアクセスキーを直接使用する方法は、セキュリティベストプラクティスではないため、
  IAMロールを使用した方法や環境変数を利用した方法を次回は実装してみたいです。

- 自宅のPCからアクセスするできるよう、すべてのサーバーにpublic ipを持たせています。
  また、セキュリティグループの設定も比較的制限がゆるくなっています。
  public subnetやprivate subnetの使い分け等を意識した構成を実現できるように
  VPN接続などのほかのサービスも利用した設計を実現できるようになりたです。
