# docker-stack-installer

複数の Docker サービス repo をまとめて確認・起動するための親 repo です。旧 `docker_container_installer_original` のようにテンプレートを大量コピーするのではなく、各 repo を正本として扱う前提に寄せています。公開入口は `infra-reverse-proxy` の `Traefik v2.11` を使います。

## 日本語メモ

GitHub のコミット一覧が英語で分かりにくい場合は、[コミット履歴の日本語メモ](docs/COMMIT_HISTORY_JA.md) を見てください。

## Quick Start

このプロジェクトの基本方針は「迷わず入る」ことです。
必要な実値はスクリプトの途中で聞かれるため、導入は次の 4 段階にします。

1. 対話式コマンド 1 本で、必要なパッケージと repo を全部そろえる
2. 質問に答える
3. 実行コマンド 1 本で、起動と確認まで行う
4. 完了

### 1. 対話式コマンド

Ubuntu 24.04 / 26.04 系のクリーンOSから始める場合も、まずこの 1 本です。
`curl` や `git` がまだ無い状態でも、このコマンド内で最小パッケージを入れてから準備を続けます。

```bash
bash -lc 'set -e; sudo apt-get update; sudo apt-get install -y ca-certificates curl; curl -fsSL https://raw.githubusercontent.com/Arrumis/docker-stack-installer/main/scripts/bootstrap-clean-ubuntu.sh | bash -s -- --owner Arrumis --guided'
```

この対話式コマンドは次をまとめて行います。

- `curl` の導入
- `git` `docker.io` `docker-compose-v2` の導入
- `docker-stack-installer` の clone / update
- sibling repo の clone
- `stack.env.local` の作成
- `stack.service.env.local` の作成
- 各 repo の `.env.local` の作成
- 必要な設定の質問
- 入力内容の env 反映
- インストール
- 起動後確認

### 2. 質問に答える

途中で聞かれる主な内容は次です。

- 公開ドメイン名
- Let's Encrypt の通知メール
- 永続データの保存先
- 録画ファイルの保存先
- Basic 認証のユーザー名とパスワード
- OpenVPN 管理者パスワード
- 入れないサービス

分からない項目は Enter で既定値を使えます。
入力した値は `stack.service.env.local` に残るため、あとから見直せます。

最後に「このままインストールと起動確認まで進めますか」と聞かれます。
ここで `Y` または Enter を押すと、そのまま最後まで進みます。
ここで `n` を選ぶと、env を確認してから手動で実行できます。

### 3. 実行コマンド

対話式の最後で `n` を選んだ場合、または env を後から編集した場合は、この 1 本で起動と確認を行います。

```bash
cd ~/docker-stack/docker-stack-installer
./scripts/run-full-stack.sh
```

この中で `install-full-stack.sh` と `verify-stack.sh` を順番に実行します。

### 4. 完了

`verify-stack.sh` が通れば、Docker 群の起動確認まで完了です。
証明書取得に必要な公開条件が揃っている場合は、`HTTP -> 証明書取得 -> HTTPS` の自動昇格も行われます。

### env を手で確認してから進めたい場合

途中入力ではなく、準備だけ行ってから自分で env を編集したい場合は `--prepare-only` を使います。

```bash
bash -lc 'set -e; sudo apt-get update; sudo apt-get install -y ca-certificates curl; curl -fsSL https://raw.githubusercontent.com/Arrumis/docker-stack-installer/main/scripts/bootstrap-clean-ubuntu.sh | bash -s -- --owner Arrumis --prepare-only'
```

準備が終わったら、通常は `stack.service.env.local` を中心に編集します。

```bash
cd ~/docker-stack/docker-stack-installer
nano stack.service.env.local
nano stack.env.local
./scripts/run-full-stack.sh
```

### 質問なしで一気に入れたい場合

検証用PCなどで、ドメインやメールをコマンドに直接渡して一気に入れることもできます。
`sample.com` は説明用の仮ドメインなので、実際に使うドメインへ置き換えます。

```bash
bash -lc 'set -e; sudo apt-get update; sudo apt-get install -y ca-certificates curl; curl -fsSL https://raw.githubusercontent.com/Arrumis/docker-stack-installer/main/scripts/bootstrap-clean-ubuntu.sh | bash -s -- --owner Arrumis --domain sample.com --email admin@sample.com'
```

HTTP のまま止めたい場合は、`--skip-https` を付けます。

```bash
bash -lc 'set -e; sudo apt-get update; sudo apt-get install -y ca-certificates curl; curl -fsSL https://raw.githubusercontent.com/Arrumis/docker-stack-installer/main/scripts/bootstrap-clean-ubuntu.sh | bash -s -- --owner Arrumis --domain sample.com --skip-https'
```

## サンプル値の置き換え

README や `.env.example` には、GitHub に公開しても安全な仮の値が入っています。これらはそのまま使う値ではありません。

| サンプル値 | 何に置き換えるか | 例 |
|---|---|---|
| `sample.com` | 実際に公開するドメイン | `ponkotu.mydns.jp` |
| `admin@sample.com` | 証明書通知を受け取れるメール | `admin@ponkotu.mydns.jp` |
| `your-github-user` | GitHub のユーザー名または owner 名 | `Arrumis` |
| `change-me` | 自分で決めた強いパスワード | GitHub には書かない |
| `/srv/docker-data` | 永続データを置く親ディレクトリ | `/mnt/data/docker-data` |
| `/srv/docker-recorded` | 録画ファイルを置くディレクトリ | `/mnt/recorded` |

まとめて変更したい値は、まず `stack.service.env.local` に書きます。

```bash
GLOBAL__DOMAIN=ponkotu.mydns.jp
GLOBAL__ROOT_HOST=ponkotu.mydns.jp
GLOBAL__LETSENCRYPT_EMAIL=admin@ponkotu.mydns.jp
GLOBAL__HOST_DATA_ROOT=/mnt/data/docker-data
GLOBAL__RECORDED_ROOT=/mnt/recorded
GLOBAL__BASIC_AUTH_USER=admin
GLOBAL__BASIC_AUTH_PASSWORD=自分で決めた強いパスワード
```

パスワードや個人環境の値は、必ず `.env.local` または `stack.service.env.local` にだけ書きます。`.env.example` は公開用の見本なので、実パスワードや個人情報は入れません。

手動ルートで clone した場合や、bootstrap 後に設定を調整して再実行したい場合は、env を環境に合わせてから次を実行します。

```bash
./scripts/run-full-stack.sh
```

`app-mirakurun-epgstation` を含める場合は、旧 `mirakurun.sh` から移したホスト準備スクリプトも実行されます。ここでは `sudo apt-get install` と `pcscd` 停止が入るため、録画環境だけはホスト側変更を伴います。

## インストール後の設定一覧

インストール後には、親 repo 直下に `local-install-summary.md` を出力します。
これはそのPCで使った設定の控えです。

```bash
less local-install-summary.md
```

このファイルにはパスワードなどの秘密情報が含まれる場合があります。
`.gitignore` に入っているため通常は GitHub へ上がりませんが、ローカル専用の控えとして扱ってください。

## 役割

- 各サービス repo の配置確認
- `compose.yaml` と `.env.local` の存在確認
- 必要なサービスだけ一括起動

## 管理対象

初期状態では以下を前提にしています。

基盤:

- `infra-reverse-proxy`
- `infra-fail2ban`
- `infra-munin`

アプリ:

- `app-tategaki`
- `app-wordpress`
- `app-ttrss`
- `app-syncthing`
- `app-openvpn`
- `app-mirakurun-epgstation`

一覧は `repos/services.tsv` で管理します。

## 初期設定

通常は Quick Start の対話式コマンドが、必要な env ファイルを自動で作ります。
手動で repo を clone した場合だけ、`stack.env.example` から `stack.env.local` を作ってください。

インストール時に触る設定ファイルは、まず次の 2 種類です。

- `stack.env.local`
  - 親 repo 用です
  - 「repo をどこへ clone するか」「どのサービスを対象にするか」のような全体設定を書きます
- `stack.service.env.local`
  - 親 repo 用です
  - 各 service repo の `.env.local` に対して、親側から優先して上書きしたい値を書きます
- 各 service repo の `.env.local`
  - 各 Docker サービス用です
  - ポート、公開ホスト名、データ保存先、DB パスワードなど、そのサービス固有の値を書きます

先に `stack.env.local` を作り、その後 `init-env-files.sh` で `stack.service.env.local` と各 service repo の `.env.local` を作る流れです。

### `stack.env.local`

`stack.env.local` は親 repo の制御用ファイルです。ここにはサービス本体の秘密情報ではなく、導入全体の動き方を書きます。

```bash
STACK_ROOT=/path/to/workspace
STACK_GITHUB_OWNER=your-github-user
CLONE_PROTOCOL=https
SERVICES="infra-reverse-proxy infra-fail2ban infra-munin app-tategaki app-wordpress app-ttrss app-syncthing app-openvpn app-mirakurun-epgstation"
AUTO_ENABLE_HTTPS=1
```

主な項目はこうです。

- `STACK_ROOT`
  - 各 repo を clone する親ディレクトリ
- `STACK_GITHUB_OWNER`
  - GitHub の owner 名
- `CLONE_PROTOCOL`
  - `https` または `ssh`
- `SERVICES`
  - 既定で管理対象にするサービス一覧
- `EXCLUDED_SERVICES`
  - 既定一覧から除外するサービス
- `AUTO_ENABLE_HTTPS`
  - `1` なら起動後に HTTPS 化を試みる

`CLONE_PROTOCOL` は `https` か `ssh` を使えます。

使わないサービスを毎回引数で並べたくない場合は、`stack.env.local` に `EXCLUDED_SERVICES` を書くと、既定の対象一覧からまとめて外せます。

```bash
EXCLUDED_SERVICES="infra-munin app-openvpn"
```

この設定は `bootstrap-repos.sh` `init-env-files.sh` `check-layout.sh` `install-full-stack.sh` `up-selected.sh` `verify-stack.sh` の既定動作に反映されます。

`AUTO_ENABLE_HTTPS=1` のときは、`infra-reverse-proxy` を含む一括起動の最後に `request-certificates.sh` を自動実行します。現在は Traefik 自身が ACME `HTTP-01` を行うため、別の `certbot` コンテナは使いません。

録画系と管理系の公開入口には Basic 認証が入ります。初期資格情報は `configure-default-envs.sh` が `infra-reverse-proxy/.env.local` に保存します。

- `BASIC_AUTH_USER`
- `BASIC_AUTH_PASSWORD`

### `stack.service.env.local`

`stack.service.env.local` は、親 repo から各サービスの値をまとめて上書きするための統括 env です。

- 書いてある項目だけ上書きします
- 書いていない項目は、各 service repo の `.env.local` をそのまま使います
- つまり「よく変える値だけを親側へ集約する」ためのファイルです
- 永続データの保存先も、ここから一括指定できます
- `GLOBAL__...` を使うと、同じ値を複数サービスへ自動で配れます

初回は次の雛形から作れます。

```bash
cp stack.service.env.example stack.service.env.local
```

書式は `サービス名を大文字化して __ を付ける` 形です。

```bash
INFRA_REVERSE_PROXY__DOMAIN=sample.com
APP_WORDPRESS__APP_PORT=8080
APP_TTRSS__TTRSS_SELF_URL_PATH=https://ttrss.sample.com/tt-rss/
```

「できるだけ 1 回だけ入力したい」なら、まずは `GLOBAL__...` を使うのがおすすめです。

```bash
GLOBAL__DOMAIN=sample.com
GLOBAL__ROOT_HOST=sample.com
GLOBAL__PUBLIC_SCHEME=https
GLOBAL__LETSENCRYPT_EMAIL=admin@sample.com
GLOBAL__BASIC_AUTH_USER=admin
GLOBAL__BASIC_AUTH_PASSWORD=change-me
GLOBAL__TZ=Asia/Tokyo
GLOBAL__PUID=1000
GLOBAL__PGID=1000
GLOBAL__PROXY_NETWORK_NAME=proxy-network
GLOBAL__HOST_DATA_ROOT=/srv/docker-data
GLOBAL__RECORDED_ROOT=/srv/docker-recorded
GLOBAL__PROXY_LOG_DIR=/srv/docker-stack/infra-reverse-proxy/data/log
```

これだけで、主に次が自動反映されます。

- reverse proxy の各ホスト名
- ttrss の `TTRSS_SELF_URL_PATH`
- munin / mirakurun / epgrec / epgstation / traefik の Basic 認証
- 各サービスの `TZ`
- Syncthing / OpenVPN の `PUID` `PGID`
- ttrss の `OWNER_UID` `OWNER_GID`
- EPGStation の `EPGSTATION_UID` `EPGSTATION_GID`
- 各サービスの `PROXY_NETWORK_NAME`
- fail2ban の `PROXY_LOG_DIR`
- 各サービスの永続データ保存先

そのうえで、「ここだけ例外にしたい」ものだけを個別に足します。

```bash
APP_WORDPRESS__APP_PORT=8080
APP_MIRAKURUN_EPGSTATION__DATA_SUBDIR=tv
APP_MIRAKURUN_EPGSTATION__RECORDED_SUBDIR=tv-recorded
```

永続データをまとめて別ディスクへ置きたい場合は、次のような一括指定も使えます。

```bash
GLOBAL__HOST_DATA_ROOT=/srv/docker-data
GLOBAL__RECORDED_ROOT=/srv/docker-recorded
```

proxy と fail2ban のログ位置をずらしたくない場合は、reverse proxy のログディレクトリも一箇所で管理できます。

```bash
GLOBAL__PROXY_LOG_DIR=/srv/docker-stack/infra-reverse-proxy/data/log
```

Docker network 名も一箇所で管理できます。proxy と各アプリは同じ network に入る必要があるため、通常はこの値を全サービスで揃えます。

```bash
GLOBAL__PROXY_NETWORK_NAME=proxy-network
```

この場合、各サービスは既定のサブディレクトリ名で自動展開されます。サブディレクトリ名だけ変えたい場合は、たとえば次のように書けます。

```bash
APP_WORDPRESS__DATA_SUBDIR=blog
APP_MIRAKURUN_EPGSTATION__DATA_SUBDIR=tv
APP_MIRAKURUN_EPGSTATION__RECORDED_SUBDIR=tv-recorded
```

優先順位は次の通りです。

1. `stack.service.env.local`
2. 各 service repo の `.env.local`
3. 各 service repo の `.env.example`

### 各 service repo の `.env.local`

各 repo の `.env.local` は、そのサービス専用の設定です。初回は次でひな型を作れます。

```bash
./scripts/init-env-files.sh
```

作られる中身は repo ごとに違いますが、意味はだいたい次の 4 系統です。

- 公開設定
  - 例: `DOMAIN`, `ROOT_HOST`, `TTRSS_HOST`, `TRAEFIK_HOST`
- ポート設定
  - 例: `APP_PORT`, `HTTP_PORT`, `HTTPS_PORT`, `MIRAKURUN_PORT`
- 永続化パス
  - 例: `HOST_DATA_DIR`, `WORDPRESS_DB_DIR`, `EPGSTATION_DATA_DIR`
- 認証情報
  - 例: `WORDPRESS_DB_PASSWORD`, `TTRSS_DB_PASS`, `BASIC_AUTH_PASSWORD`

編集するときの目安はこうです。

- 親 repo の動きを変えたい
  - `stack.env.local`
- WordPress だけポートや DB パスワードを変えたい
  - `app-wordpress/.env.local`
- proxy の公開ホスト名や Basic 認証を変えたい
  - `infra-reverse-proxy/.env.local`
- 録画データの保存先を変えたい
  - `app-mirakurun-epgstation/.env.local`

パスワードや実運用値は `.env.example` ではなく `.env.local` にだけ入れます。`.env.example` は雛形で、Git に入れてよい値だけを残す前提です。

## リポジトリ取得 / 更新

新しい PC では、まず sibling repo をまとめて clone できます。

```bash
./scripts/bootstrap-repos.sh
```

既に clone 済みの repo がある場合は `git pull --ff-only` で更新します。

## env ファイル初期化

`.env.local` がない repo には、`.env.example` からひな型を作れます。

```bash
./scripts/init-env-files.sh
```

作成後に、各 repo の `.env.local` を環境に合わせて編集します。

## 新PC診断

まず依存コマンド、Docker 権限、repo 配置を確認できます。

```bash
./scripts/doctor.sh
```

続けて、各 repo の `compose.yaml` と `.env.local` を使ったスモークテストを行えます。

```bash
./scripts/smoke-test.sh
./scripts/smoke-test.sh --pull
```

詳細な流れは `TEST_PC_CHECKLIST.md` にまとめています。

## レイアウト確認

```bash
./scripts/check-layout.sh
```

特定サービスだけ確認することもできます。

```bash
./scripts/check-layout.sh app-tategaki app-wordpress
```

## 一括起動

```bash
./scripts/up-selected.sh
```

検証で通した推奨順に、bootstrap / env 初期化 / doctor / layout check / 起動 / 起動後確認 / 設定一覧出力までまとめて流す場合:

```bash
./scripts/run-full-stack.sh
```

すでに repo と `.env.local` が揃っている場合は、前段を飛ばして起動だけできます。

```bash
./scripts/install-full-stack.sh --skip-bootstrap --skip-init-env --skip-doctor --skip-check
```

特定サービスだけ起動する場合:

```bash
./scripts/up-selected.sh app-tategaki app-ttrss
```

既定一覧から一部だけ外して運用したい場合は、引数ではなく `stack.env.local` の `EXCLUDED_SERVICES` を使うのが楽です。

## 起動後確認

主要サービスの入口だけ再確認するには:

```bash
./scripts/verify-stack.sh
```

`infra-reverse-proxy` の Traefik が `443` を持っていれば HTTPS で検証し、まだ証明書がない新規マシンでは HTTP で検証します。

Basic 認証がかかる `munin` `mirakurun` `epgrec` `epgstation` `traefik` については、`verify-stack.sh` が `infra-reverse-proxy/.env.local` の資格情報を自動で使います。

手元に別回線がなく、外からの到達確認ができない場合は、GitHub Actions の `Public Endpoint Check` を使えます。これは GitHub の外部 runner から次を確認します。

- `https://sample.com/`
- `https://ttrss.sample.com/tt-rss/`
- `https://munin.sample.com/`
- `https://tategaki.sample.com/`
- `https://syncthing.sample.com/`
- `https://openvpn.sample.com/`
- `https://traefik.sample.com/dashboard/`
- `https://mirakurun.sample.com/`
- `https://epgrec.sample.com/`
- `https://epgstation.sample.com/`

手元から試す場合は:

```bash
./scripts/check-public-urls.sh
```

## 切替前確認

既存の live 環境とポートが衝突するかを確認できます。

```bash
./scripts/preflight-cutover.sh
```

特定サービスだけ見る場合:

```bash
./scripts/preflight-cutover.sh app-wordpress app-ttrss
```

## 旧構成からの切替

サービス単位で、旧 compose を止めて新 repo を起動する cutover スクリプトを用意しています。

まずは dry-run:

```bash
./scripts/cutover-service.sh app-wordpress
```

実行する場合:

```bash
./scripts/cutover-service.sh --apply app-wordpress
```

rollback も同様です。

```bash
./scripts/rollback-to-legacy.sh app-wordpress
./scripts/rollback-to-legacy.sh --apply app-wordpress
```

この cutover 系スクリプトを使う場合は、`repos/legacy-services.example.tsv` を `repos/legacy-services.local.tsv` にコピーして、旧 compose のパスをそのマシン用に設定します。

## 方針

- 正本は各サービス repo
- 親 repo は orchestration のみ
- 実データや秘密情報は各 repo の `.env.local` と `data/` 側で管理
- 新しい PC では対話式コマンド 1 本 -> 質問に回答 -> `run-full-stack.sh` の流れで復元する
- live 環境の切替は `preflight-cutover.sh` で衝突確認してから、`cutover-service.sh --apply <service>` をサービス単位で進める
