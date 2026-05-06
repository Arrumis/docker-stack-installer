# docker-stack-installer

複数の Docker サービス用リポジトリをまとめて準備、設定、起動、確認する親リポジトリです。
各サービスのリポジトリを正本として扱い、この親リポジトリは全体をつなぐ入口になります。

## 対象リポジトリ

標準では次を扱います。

- `infra-reverse-proxy`: 公開入口と証明書
- `infra-fail2ban`: 攻撃元 IP アドレスの遮断と Discord 通知
- `infra-munin`: 監視画面
- `app-wordpress`: WordPress
- `app-ttrss`: Tiny Tiny RSS
- `app-tategaki`: 縦書き小説リーダー
- `app-syncthing`: Syncthing
- `app-openvpn`: OpenVPN Access Server
- `app-mirakurun-epgstation`: Mirakurun と EPGStation

## 最短手順

Ubuntu 24.04 / 26.04 系の新しい環境では、まず次を実行します。

```bash
bash -lc 'set -e; sudo apt-get update; sudo apt-get install -y ca-certificates curl; curl -fsSL https://raw.githubusercontent.com/Arrumis/docker-stack-installer/main/scripts/bootstrap-clean-ubuntu.sh | bash -s -- --owner Arrumis --guided'
```

このコマンドで行うこと:

- 必要なパッケージを入れる
- このリポジトリと各サービス用リポジトリを取得する
- `stack.env.local` と `stack.service.env.local` を作る
- 各サービスの `.env.local` を作る
- 対話式で必要な値を聞く
- Docker サービスを起動する
- 起動確認を行う

途中で聞かれる主な内容:

- 公開ドメイン名
- 証明書通知を受け取るメールアドレス
- 永続データの保存先
- 録画ファイルの保存先
- Basic 認証のユーザー名とパスワード
- OpenVPN 管理者パスワード
- 今回インストールしないサービス

分からない項目は Enter で既定値を使えます。

## 後から再実行する場合

設定を直したあと、起動と確認をまとめて行います。

```bash
cd ~/docker-stack/docker-stack-installer
./scripts/run-full-stack.sh
```

準備だけ行ってから手で設定したい場合:

```bash
bash -lc 'set -e; sudo apt-get update; sudo apt-get install -y ca-certificates curl; curl -fsSL https://raw.githubusercontent.com/Arrumis/docker-stack-installer/main/scripts/bootstrap-clean-ubuntu.sh | bash -s -- --owner Arrumis --prepare-only'
```

その後で `stack.service.env.local` を編集します。

```bash
cd ~/docker-stack/docker-stack-installer
nano stack.service.env.local
./scripts/run-full-stack.sh
```

## 変更する値

公開用の見本には、GitHub に上げてもよい仮の値だけを書いています。
実際の値は `stack.env.local` または `stack.service.env.local` に書きます。

よく変更する値:

- `GLOBAL__DOMAIN`: 公開するドメインです。
- `GLOBAL__ROOT_HOST`: 親ドメイン直下で使うホスト名です。
- `GLOBAL__LETSENCRYPT_EMAIL`: 証明書通知を受け取るメールアドレスです。
- `GLOBAL__HOST_DATA_ROOT`: 各サービスの永続データを置く親ディレクトリです。
- `GLOBAL__RECORDED_ROOT`: 録画ファイルを置くディレクトリです。
- `GLOBAL__BASIC_AUTH_USER` と `GLOBAL__BASIC_AUTH_PASSWORD`: 管理系画面の認証情報です。
- `GLOBAL__DISCORD_WEBHOOK_URL`: fail2ban の通知先 Discord Webhook URL です。

パスワードや Discord Webhook URL は秘密値です。GitHub に上げるファイルへは書きません。

## 既存 HDD を使う場合

既存データを使う場合も、基本は対話式の導入を使います。
このリポジトリのスクリプトは、既存データの削除や大規模なコピーを勝手には行いません。

標準の保存先名:

- WordPress: `wp/html`、`wp/db_data`
- Tiny Tiny RSS: `ttrss/ttrss_app`、`ttrss/ttrss_db`、`ttrss/config.d`
- tategaki: `tategaki`
- Syncthing: `sync/config`、`sync/data`
- OpenVPN: `openvpn`
- Mirakurun / EPGStation: `mirakurun/*`、`epgstation/*`、`recorded`

WordPress のデータベースは、稼働中のディレクトリをそのままコピーせず、ダンプから復元します。
詳しくは `app-wordpress` の README を見てください。

録画系はホスト側のチューナードライバや `pcscd` 停止が必要です。
この部分だけは、Docker の外側にも変更が入ります。

## 生成される控え

インストール後に `local-install-summary.md` を作ります。
そのパソコンで使った設定を確認するための控えです。

```bash
less local-install-summary.md
```

このファイルは GitHub に上げない設定です。

## よく使う確認

全体の配置を確認します。

```bash
./scripts/check-layout.sh
```

起動状態を確認します。

```bash
./scripts/verify-stack.sh
```

公開 URL を確認します。

```bash
./scripts/check-public-urls.sh
```

## 補足

- GitHub のコミット履歴が英語で分かりにくい場合は、`docs/COMMIT_HISTORY_JA.md` を見てください。
- この親リポジトリだけで完結するのではなく、各サービス用リポジトリと合わせて使います。
- 個別サービスの細かい設定は、それぞれの README と `.env.example` を確認します。
