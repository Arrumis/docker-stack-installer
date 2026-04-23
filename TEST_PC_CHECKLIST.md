# Test PC Checklist

新しい PC で実行テストをするときの最短手順です。

## 1. 親 repo を clone

```bash
git clone https://github.com/Arrumis/docker-stack-installer.git
cd docker-stack-installer
cp stack.env.example stack.env.local
```

必要なら `stack.env.local` の `STACK_ROOT` をそのPC向けに調整します。

## 2. 分離済み repo を取得

```bash
./scripts/bootstrap-repos.sh
./scripts/init-env-files.sh
```

## 3. 事前診断

```bash
./scripts/doctor.sh
```

確認ポイント:

- `docker` と `docker compose` が使える
- 対象 repo が clone されている
- `proxy-network` が必要なら存在する
- `infra-reverse-proxy` は Traefik v2.11 前提で起動する

## 4. スモークテスト

まずは構文確認だけ:

```bash
./scripts/smoke-test.sh
```

イメージ取得も含める場合:

```bash
./scripts/smoke-test.sh --pull
```

## 5. `.env.local` の実値調整

各 repo の `.env.local` に以下を反映します。

- ドメイン
- ポート
- データ保存先
- パスワード / webhook などの秘密情報
- 録画系のデバイスパス

## 6. 一括起動

```bash
./scripts/install-full-stack.sh
```

録画環境を含む場合は、ここで `app-mirakurun-epgstation/scripts/prepare-host.sh` が自動実行され、`sudo apt-get install` と `pcscd` 停止が走ります。

特定サービスだけ試すなら:

```bash
./scripts/install-full-stack.sh --skip-bootstrap --skip-init-env --skip-doctor --skip-check app-wordpress app-ttrss
```

## 7. 起動後確認

```bash
./scripts/verify-stack.sh
```

確認できる内容:

- `ponkotu.mydns.jp` / `ttrss.*` / `munin.*` の proxy 経由応答
- `tategaki.*` / `syncthing.*` / `openvpn.*` / `epgstation.*` の proxy 経由応答
- `traefik.*` の dashboard 応答
- Syncthing / OpenVPN / Tategaki のローカル応答
- Mirakurun API / EPGStation のローカル応答

Traefik が `443` を持っていれば HTTPS を確認し、証明書がまだない新規マシンでは HTTP で確認します。

## 8. live 環境を置き換える場合

既存の本番機で port conflict を避けて切り替えるときは:

```bash
./scripts/preflight-cutover.sh
./scripts/cutover-service.sh app-wordpress
./scripts/cutover-service.sh --apply app-wordpress
```
