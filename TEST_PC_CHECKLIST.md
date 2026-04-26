# Test PC Checklist

新しい PC で実行テストをするときの最短手順です。

## 1. 対話式コマンド 1 本で始める

完全クリーンOSでは `git` や `curl` が無い場合があります。
次の 1 本は、最小パッケージの導入、repo の取得、env ファイルの作成、必要値の質問、インストール、起動確認までまとめて行います。

```bash
bash -lc 'set -e; sudo apt-get update; sudo apt-get install -y ca-certificates curl; curl -fsSL https://raw.githubusercontent.com/Arrumis/docker-stack-installer/main/scripts/bootstrap-clean-ubuntu.sh | bash -s -- --owner Arrumis --guided'
```

`--owner Arrumis` は、GitHub の `Arrumis` 配下にある repo 群を取得するという意味です。
この repo 群をそのまま使うなら変更しません。
fork して別アカウントで管理する場合だけ置き換えます。

途中で聞かれる内容に答えます。
分からない項目は Enter で既定値を使えます。
保存先には `~/docker-data` のような `~/` 付きパスも使えます。
入力後は `/home/ユーザー名/...` の絶対パスへ変換されます。

「インストールしないDocker」は、今回入れないサービス名を空白区切りで書く欄です。
空のまま Enter なら全部入ります。
対話式では、現在設定されている管理対象サービス一覧が表示されます。
例: `app-openvpn app-syncthing`

通常の clone 先は `~/docker-stack/docker-stack-installer` です。

```bash
cd ~/docker-stack/docker-stack-installer
```

## 2. 設定一覧を確認する

インストールが終わると、設定控えが出力されます。
パスワード類も含まれる場合があるため、GitHubへ上げないローカル専用の控えとして扱います。

```bash
less local-install-summary.md
```

あとから値を直したい場合は、まず `stack.service.env.local` を編集します。
ドメイン、保存先、ID、パスワードなど、各 Docker に共通で使い回す値はここに書きます。

```bash
nano stack.service.env.local
nano stack.env.local
```

確認ポイント:

- `GLOBAL__DOMAIN` が実際のドメインになっている
- `GLOBAL__LETSENCRYPT_EMAIL` が自分のメールになっている
- `GLOBAL__HOST_DATA_ROOT` が永続データ保存先になっている
- `GLOBAL__RECORDED_ROOT` が録画保存先になっている
- `GLOBAL__BASIC_AUTH_USER` と `GLOBAL__BASIC_AUTH_PASSWORD` を設定している
- 使わない Docker は `EXCLUDED_SERVICES` に書いている。空なら全部入る

## 3. 再実行する場合

env 編集後に再実行する場合は、この 1 本でインストール、起動、起動後確認、設定一覧の再出力まで進めます。

```bash
./scripts/run-full-stack.sh
```

録画環境を含む場合は、ここで `app-mirakurun-epgstation/scripts/prepare-host.sh` が自動実行され、`sudo apt-get install` と `pcscd` 停止が走ります。

特定サービスだけ試す場合は、実行コマンドへサービス名を渡します。

```bash
./scripts/run-full-stack.sh app-wordpress app-ttrss
```

## 4. 完了

`run-full-stack.sh` の最後に `verify-stack.sh` が走ります。
これが通り、`local-install-summary.md` が出ていれば、新しい PC での導入確認は完了です。

確認できる内容:

- `sample.com` / `ttrss.*` / `munin.*` の proxy 経由応答
- `tategaki.*` / `syncthing.*` / `openvpn.*` / `epgstation.*` の proxy 経由応答
- `traefik.*` の dashboard 応答
- Syncthing / OpenVPN / Tategaki のローカル応答
- Mirakurun API / EPGStation のローカル応答

Traefik が `443` を持っていれば HTTPS を確認し、証明書がまだない新規マシンでは HTTP で確認します。

## 補助: 事前確認だけしたい場合

構文確認だけ行いたい場合:

```bash
./scripts/smoke-test.sh
```

イメージ取得も含める場合:

```bash
./scripts/smoke-test.sh --pull
```

事前診断だけ再実行したい場合:

```bash
./scripts/doctor.sh
```

## 補助: live 環境を置き換える場合

既存の本番機で port conflict を避けて切り替えるときは:

```bash
./scripts/preflight-cutover.sh
./scripts/cutover-service.sh app-wordpress
./scripts/cutover-service.sh --apply app-wordpress
```
