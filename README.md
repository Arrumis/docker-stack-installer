# docker-stack-installer

複数の Docker サービス repo をまとめて確認・起動するための親 repo です。旧 `docker_container_installer_original` のようにテンプレートを大量コピーするのではなく、各 repo を正本として扱う前提に寄せています。

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
- `app-txtmiru-with-narourb`
- `app-mirakurun-epgstation`

一覧は [repos/services.tsv](/home/hiyori2023/docker-stack-installer/repos/services.tsv:1) で管理します。

## 初期設定

```bash
cp stack.env.example stack.env.local
```

`stack.env.local` では repo を配置した親ディレクトリを指定します。

```bash
STACK_ROOT=/home/hiyori2023
STACK_GITHUB_OWNER=Arrumis
CLONE_PROTOCOL=https
SERVICES="infra-reverse-proxy infra-fail2ban infra-munin app-tategaki app-wordpress app-ttrss app-syncthing app-openvpn app-txtmiru-with-narourb app-mirakurun-epgstation"
```

`CLONE_PROTOCOL` は `https` か `ssh` を使えます。

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

特定サービスだけ起動する場合:

```bash
./scripts/up-selected.sh app-tategaki app-ttrss
```

## 方針

- 正本は各サービス repo
- 親 repo は orchestration のみ
- 実データや秘密情報は各 repo の `.env.local` と `data/` 側で管理
- 新しい PC では `bootstrap-repos.sh` -> `init-env-files.sh` -> 各 `.env.local` 調整 -> `up-selected.sh` の流れで復元する
