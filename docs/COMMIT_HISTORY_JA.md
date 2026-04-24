# コミット履歴の日本語メモ

このファイルは、GitHub のコミット一覧が英語だけだと後から読みにくいため、日本語で「何をしたか」を追えるようにしたメモです。

注意点として、既存のコミットメッセージ自体を直接直すには Git の履歴作り直しと force push が必要です。ここでは安全のため、履歴は壊さず、日本語の説明を追加しています。

## これまでの主な変更

| コミット | 英語の表示 | 日本語でいうと |
|---|---|---|
| `da07b7a` | Initial import for repo split | repo 分割用に最初の内容を取り込み |
| `b1fd3dc` | Add infra-munin to managed services | 管理対象サービスに Munin を追加 |
| `cd7b809` | Add bootstrap and env initialization helpers | repo 取得と env 初期化の補助スクリプトを追加 |
| `f8c3d38` | Add test PC diagnostics and cutover helpers | テスト PC の診断と切り替え補助を追加 |
| `9048c63` | Add quick start to README | README にクイックスタートを追加 |
| `8658515` | Prepare repository for public release | 公開 repo 向けに整理 |
| `44945f6` | Add full stack installer flow | 全サービス一括インストールの流れを追加 |
| `fd4511f` | Run recording host prep during install | 録画環境のホスト準備をインストール時に実行 |
| `5dc8b1f` | Reload proxy after config changes | 設定変更後に proxy を再読み込み |
| `9c923f1` | Add post-install verification guide | インストール後の確認手順を追加 |
| `29c9a90` | Remove txtmiru from managed stack | txtmiru を管理対象から除外 |
| `b0e94c1` | Remove txtmiru leftovers from stack | txtmiru の残り設定を削除 |
| `fc9b80c` | Support excluding default services | 不要サービスを除外できる仕組みを追加 |
| `155bd74` | Add clean Ubuntu bootstrap flow | クリーン Ubuntu からの導入手順を追加 |
| `fa68850` | Retry recording checks during stack verification | 録画系チェックをリトライするよう改善 |
| `2443583` | Automate HTTP to HTTPS promotion | HTTP から HTTPS への昇格を自動化 |
| `a47649c` | Add GitHub-based public endpoint checks | GitHub Actions で公開 URL を確認する仕組みを追加 |
| `c8a9b40` | Add GitHub-based public endpoint checks | 公開 URL 確認の GitHub Actions を追加 |
| `0c6dbf5` | Document GitHub-based public endpoint checks | 公開 URL 確認の使い方を文書化 |
| `863572d` | Fix public endpoint workflow execution | 公開 URL 確認 workflow の実行権限を修正 |
| `b6ea02c` | Update public URL checks for Mirakurun and EPGStation | Mirakurun / EPGStation の公開 URL 確認を更新 |
| `32e4a7a` | Configure separate Mirakurun and EPGStation proxy hosts | Mirakurun と EPGStation の proxy ホストを分離 |
| `f7b620f` | Capture TTRSS admin password after startup | ttrss 起動後に admin パスワードを保存 |
| `225dc72` | Verify separate Mirakurun and EPGStation proxy endpoints | 分離した Mirakurun / EPGStation の接続確認を追加 |
| `d6bcb42` | Configure Traefik-compatible proxy dashboard host | Traefik dashboard 用ホストを設定 |
| `6a48b17` | Verify Traefik-compatible proxy dashboard host | Traefik dashboard ホストの確認を追加 |
| `a6f11d1` | Check Traefik-compatible proxy dashboard endpoint | Traefik dashboard の endpoint 確認を追加 |
| `11e0ef4` | Document Traefik-compatible proxy host and HTTPS fallback | Traefik ホストと HTTPS 失敗時の扱いを文書化 |
| `f1676ea` | Clarify HTTPS fallback messaging | HTTPS 失敗時メッセージを分かりやすく修正 |
| `3126c0c` | Adjust proxy checks for Traefik dashboard | Traefik dashboard 用に proxy 確認を調整 |
| `2b8c1fd` | Adjust public endpoint checks for Traefik dashboard | Traefik dashboard 用に公開 endpoint 確認を調整 |
| `0d3fa45` | Fix Traefik proxy verification scripts | Traefik proxy 確認スクリプトを修正 |
| `06e0e86` | Relax Traefik dashboard verification | Traefik dashboard 確認を少し緩くして失敗しにくく修正 |
| `1f9302f` | Update Traefik-based setup docs | Traefik 前提の導入文書を更新 |
| `3373f4e` | Support protected proxy routes in installer checks | Basic 認証付き proxy route の確認に対応 |
| `3d4fe1e` | Add safer myIP PPTP bootstrap helpers | myIP PPTP 導入補助を安全寄りに追加 |
| `ce01b74` | Document how to find Interlink myIP server info | Interlink myIP のサーバー情報確認方法を文書化 |
| `e1197b5` | Clarify install env files and drop myIP repo wiring | インストール用 env 説明を整理し、myIP 連携を repo から外す |
| `3d2cd34` | Improve env file guidance and comments | env ファイルの説明コメントを改善 |
| `02dad75` | Expand unified env documentation | 統括 env の説明を拡充 |
| `31ddb95` | Add practical examples to unified env docs | 統括 env に実用例を追加 |
| `a741012` | Support global data roots in unified env | 統括 env でデータ保存先の一括指定に対応 |
| `9410bf3` | Sanitize sample domains and owner placeholders | 個人ドメインや owner 名をサンプル値へ置換 |
| `70f5ee6` | Sanitize public endpoint workflow defaults | 公開 URL 確認 workflow の既定値を安全なサンプルへ変更 |
| `83731eb` | Support global unified env defaults | 統括 env の共通既定値を各サービスへ配れるよう対応 |
| `ce3af25` | Ignore unified env local file and auth-aware public checks | 統括 env の local ファイルを Git 対象外にし、認証付き公開確認に対応 |
| `2ce0f49` | Localize public endpoint workflow labels | 公開 URL 確認 workflow の表示文言を日本語化 |

