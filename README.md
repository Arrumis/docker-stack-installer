# docker-stack-installer

複数の Docker サービス repo をまとめて確認・起動するための親 repo です。旧 `docker_container_installer_original` のようにテンプレートを大量コピーするのではなく、各 repo を正本として扱う前提に寄せています。

## Quick Start

最初にインストールする repo はこれです。新しい PC では、まずこの repo を clone してから他の repo を取得します。

```bash
git clone https://github.com/Arrumis/docker-stack-installer.git
cd docker-stack-installer
cp stack.env.example stack.env.local
./scripts/bootstrap-repos.sh
./scripts/init-env-files.sh
./scripts/doctor.sh
./scripts/smoke-test.sh
```

Ubuntu 24.04 系のクリーンOSから、そのまま Docker 導入込みで始める場合は次でも入れられます。

```bash
curl -fsSL https://raw.githubusercontent.com/Arrumis/docker-stack-installer/main/scripts/bootstrap-clean-ubuntu.sh | bash -s -- --domain ponkotu.mydns.jp
```

この bootstrap は次をまとめて行います。

- `git` `docker.io` `docker-compose-v2` の導入
- `docker-stack-installer` の clone / update
- sibling repo の clone
- `.env.local` の初期化
- `ponkotu.mydns.jp` 前提の基本値投入
- `install-full-stack.sh` と `verify-stack.sh` の実行
- 公開条件が揃っていれば `HTTP -> 証明書取得 -> HTTPS` の自動昇格

必要なら追加オプションも使えます。

```bash
curl -fsSL https://raw.githubusercontent.com/Arrumis/docker-stack-installer/main/scripts/bootstrap-clean-ubuntu.sh | bash -s -- \
  --domain ponkotu.mydns.jp \
  --email admin@ponkotu.mydns.jp \
  --exclude-services "infra-munin app-openvpn"
```

HTTP のまま止めたい場合は、`--skip-https` を付けます。

```bash
curl -fsSL https://raw.githubusercontent.com/Arrumis/docker-stack-installer/main/scripts/bootstrap-clean-ubuntu.sh | bash -s -- \
  --domain ponkotu.mydns.jp \
  --skip-https
```

そのあと、各 repo の `.env.local` を環境に合わせて調整し、まとめて起動します。

```bash
./scripts/install-full-stack.sh
./scripts/verify-stack.sh
```

ひととおり自動で進めたい場合は、親 repo からまとめて実行できます。

```bash
./scripts/install-full-stack.sh
```

`app-mirakurun-epgstation` を含める場合は、旧 `mirakurun.sh` から移したホスト準備スクリプトも実行されます。ここでは `sudo apt-get install` と `pcscd` 停止が入るため、録画環境だけはホスト側変更を伴います。

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

```bash
cp stack.env.example stack.env.local
```

`stack.env.local` では repo を配置した親ディレクトリを指定します。

```bash
STACK_ROOT=/path/to/workspace
STACK_GITHUB_OWNER=Arrumis
CLONE_PROTOCOL=https
SERVICES="infra-reverse-proxy infra-fail2ban infra-munin app-tategaki app-wordpress app-ttrss app-syncthing app-openvpn app-mirakurun-epgstation"
AUTO_ENABLE_HTTPS=1
```

`CLONE_PROTOCOL` は `https` か `ssh` を使えます。

使わないサービスを毎回引数で並べたくない場合は、`stack.env.local` に `EXCLUDED_SERVICES` を書くと、既定の対象一覧からまとめて外せます。

```bash
EXCLUDED_SERVICES="infra-munin app-openvpn"
```

この設定は `bootstrap-repos.sh` `init-env-files.sh` `check-layout.sh` `install-full-stack.sh` `up-selected.sh` `verify-stack.sh` の既定動作に反映されます。

`AUTO_ENABLE_HTTPS=1` のときは、`infra-reverse-proxy` を含む一括起動の最後に `request-certificates.sh` を自動実行します。証明書取得に失敗した場合は導入全体は止めず、そのまま HTTP モードを維持します。

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

検証で通した推奨順に、bootstrap / env 初期化 / doctor / layout check / 起動までまとめて流す場合:

```bash
./scripts/install-full-stack.sh
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

主要サービスの入口をまとめて確認するには:

```bash
./scripts/verify-stack.sh
```

`infra-reverse-proxy` に既存証明書が残っているマシンでは HTTPS で検証し、証明書がまだない新規マシンでは HTTP で検証します。

手元に別回線がなく、外からの到達確認ができない場合は、GitHub Actions の `Public Endpoint Check` を使えます。これは GitHub の外部 runner から次を確認します。

- `https://ponkotu.mydns.jp/`
- `https://ttrss.ponkotu.mydns.jp/tt-rss/`
- `https://munin.ponkotu.mydns.jp/`
- `https://tategaki.ponkotu.mydns.jp/`
- `https://syncthing.ponkotu.mydns.jp/`
- `https://openvpn.ponkotu.mydns.jp/`
- `https://epgstation.ponkotu.mydns.jp/`

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
- 新しい PC では `bootstrap-repos.sh` -> `init-env-files.sh` -> 各 `.env.local` 調整 -> `up-selected.sh` の流れで復元する
- live 環境の切替は `preflight-cutover.sh` で衝突確認してから、`cutover-service.sh --apply <service>` をサービス単位で進める
