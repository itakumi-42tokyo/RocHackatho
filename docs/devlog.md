# ScreenJail 開発ログ

ハッカソン後の発表に使うための記録。**何を決めたか・なぜそうしたか・何にハマってどう直したか**を、起きた順に残す。
新しい出来事は一番下に追記する（書き方は末尾の「記録ルール」）。

- 日付: 2026-10-18
- テーマ: 管理者が Rails の画面から、参加者の Android スマホを全画面のロック画面で覆う。ロックされた人は抜け道を探し、管理者は塞ぐ「脱獄ゲーム」
- 体制: 人間 + Claude Code（設計・Rails の実装は Claude、Android のビルドと実機確認は人間）

---

## 発表用ストーリー（骨子）

1. **きっかけ**: Kaigi on Rails 2026 で聞いた「ActionCableの相手はブラウザだけじゃない」（yujiteshima さん）
2. **やりたいこと**: Rails から他人のスマホ画面をロックしたい
3. **最初の壁**: Web アプリでは OS のロックはかけられない → どこまでなら「使えなく」できるかを 3 段階で比較
4. **選んだ方式**: 全画面オーバーレイ。抜け道が残る → それを逆手に取って「脱獄ゲーム」にした
5. **UI の作り方**: ロック画面は Rails で描画し、アプリは WebView で表示するだけ → アプリを再ビルドせずに見た目を変えられる
6. **講演の教訓を実際に踏んだ**: Origin なしの接続は拒否される、など
7. **ハマりどころ**: json gem 3.x と Rails 8.0 の非互換、ngrok の ERR_NGROK_3200
8. **デモ**: （ここに当日のデモ内容を書く）
9. **まとめ**: （ここに学びを書く）

---

## タイムライン

### フェーズ 0: 情報収集（Kaigi on Rails 2026 のふりかえり）
- 聴講メモ（Day1 / Day2）とスライド写真 4 枚を、Claude にテキストへ書き起こしてもらい、公式スケジュールと突き合わせて整理した
  → `docs/kaigi-on-rails-2026/notes.md`
- 特に参考にした発表: yujiteshima「ActionCableの相手はブラウザだけじゃない — Railsでデバイス群をリアルタイム管制する」
  - Turbo Streams と raw ActionCable の使い分け（"The rule"）
  - ブラウザ以外のクライアントで壊れた 3 つ: Origin、half-open（切断に気づかない）、時刻
  - サーバーが切断に気づくまでの時間: Linux の既定では約 16 分、ping/pong ありで 4〜8 秒

### フェーズ 1: アイデア出し
- 最初の案は 3 つ: リアクションボード、スマホの死活監視ボード、AI 聴講ノート
- 人間の希望で方向転換: **「管理者が Rails の画面から、他の端末のスマホ画面をロックしたい」**
- 審査のない、楽しむためのハッカソンなので「面白さ」を優先することにした

### フェーズ 2: 「本当にロックできるのか？」の検討
Web アプリから OS のロック画面はかけられない。Android で取れる方法を比較した。

| レベル | 方法 | 使えなさ | 判断 |
|---|---|---|---|
| ① 画面を消す | adb の `KEYCODE_SLEEP` / `lockNow()` | 本人が PIN を入れればすぐ戻れる | 不採用 |
| ② 全画面で覆う | 「他のアプリの上に重ねて表示」で全画面オーバーレイ | ほぼ操作不能。ただし通知バーや再起動など抜け道あり | **採用** |
| ③ キオスクモード | Device Owner + Lock Task Mode | 完全に操作不能 | 端末の初期化が必要なので不採用 |

②で調べてわかったこと:
- **戻るボタンは無効にできる**（オーバーレイがキーを受け取って握りつぶす）
- **ホームボタンは止められない**が、押してもオーバーレイは上に残る
- **通知バー、機内モード、実行中アプリからの停止は止められない** → 抜け道
- 「見えないけど下の UI を操作できる」状態は、Android 12 以降は不透明度 80% を超えると OS が防ぐ（タップジャッキング対策）

**決定**: ②を採用し、抜け道を逆に遊びにする。
- 🚨 **脱獄ゲーム**: 抜け道で脱出するとサーバーが検知し、脱獄タイムでランキング
- 👻 **透け透けモード**: 管理者がスライダーでロックの「濃さ（不透明度）」を変える

### フェーズ 3: 設計と CLAUDE.md
- 構成: `server/`（Rails 8）と `android/`（Kotlin）に分ける
- 講演の教訓を設計に入れた
  - **Origin チェックは無効にしない**。Android 側で Origin ヘッダーを明示して接続する
  - **自分の接続 ID が一致するときだけ offline にする**（再接続後に古い接続が閉じて誤判定するのを防ぐ）
  - ハートビート 3 秒、15 秒で inactive、60 秒で offline
  - サーバーからは「命令」ではなく「現在の状態」をまるごと送る（取りこぼしても次で追いつく）
- 4 時間の進め方を決めた。「管理画面から実機をロックできる」まで面白要素には手を出さない
- これらを `CLAUDE.md` にまとめ、Claude が毎回参照する前提にした

### フェーズ 4: Rails のセットアップ（〜09:50 ごろ）
- `rails new server`（SQLite、Propshaft、importmap、CSS フレームワークなし）
- **開発環境でも Solid Cable + Solid Queue を使う設定にした**
  - 理由: 死活判定の定期ジョブは Solid Queue で動き、ワーカーは別プロセス。開発環境の既定の async Cable だと、ジョブからの通知がブラウザやアプリに届かない
- `bin/dev` で Puma の中から Solid Queue も起動するようにした（`SOLID_QUEUE_IN_PUMA=1`）
- **UI を後から変えやすくする土台を作った**
  - 色・文字・余白は `tokens.css` の CSS 変数に集約。テーマは `data-theme` 属性で切り替え（`jail` / `kaigi`）
  - ロック画面は partial（スロット）の組み合わせ: `lock/_screen` → `_title` / `_message` / `_footer`
  - **ロック画面は Rails で描画して、Android は WebView で表示するだけにする**と決めた → アプリを再ビルドせずに見た目を変えられる
  - `/lock_preview?theme=jail` で見た目を PC からも確認できる

#### 🐛 ハマり 1: すべてのページが 500 エラー
- **症状**: 起動直後、どのページを開いても 500。Solid Queue のワーカーも起動時にエラー
- **エラー**: `ArgumentError (unknown keyword: quirks_mode)`（`ActiveSupport::JSON.encode` の中）
- **原因**: `rails new` で最新の **json gem 3.1.0** が入った。json 3.x は `quirks_mode` オプションを削除したが、Rails 8.0.5 の ActiveSupport はまだそれを渡している
- **対処**: Gemfile で `gem "json", "~> 2.10"` に固定 → json 2.21.2 になり解消
- **学び**: 「最新の gem を入れたら壊れる」は普通に起きる。エラーのバックトレースから gem の CHANGES.md を見に行くと早い

#### ✅ 確認: Origin チェックが講演どおりに動くか
WebSocket のハンドシェイクを curl で送って確認した。

| Origin | 結果 |
|---|---|
| `https://xxxx.ngrok-free.app`（許可したもの） | 101 Switching Protocols（接続 OK） |
| `https://evil.example.com` | 拒否 |
| なし（Android アプリと同じ状況） | **拒否** |

→ 講演で聞いた「ブラウザは Origin を送るが、デバイスは送らないので ActionCable に弾かれる」を、手元で再現できた。

### フェーズ 5: スマホからのアクセス（09:55 ごろ）

#### 🐛 ハマり 2: ERR_NGROK_3200「エンドポイントはオフラインです」
- **症状**: スマホで ngrok の URL を開くと `ERR_NGROK_3200`
- **原因**: その時点で ngrok のプロセスが動いていなかった（Rails は動いていた）。3200 は「URL に対応するトンネルが今は存在しない」という意味
- **対処**: `ngrok http 3000` を起動し直した → `https://precision-map-wildness.ngrok-free.dev/lock_preview` が 200 で表示された
- **学び**: 3200 が出たら、まず ngrok を起動しているターミナルが生きているかを見る。無料プランでもアカウントごとに固定の `*.ngrok-free.dev` ドメインが割り当てられるので、URL は毎回同じになる
- **メモ**: 無料プランの ngrok はブラウザで初回アクセス時に警告ページを挟む。Android の WebView や OkHttp からは `ngrok-skip-browser-warning` ヘッダーを付けて回避する

### フェーズ 6: Android アプリの雛形とロック画面（10:00〜13:10 ごろ）
- `android/` に Kotlin プロジェクトを作成（最小構成。OkHttp だけ追加）
- **ロック画面の見た目は Rails、Android は WebView で表示するだけ**という方針を実装に反映
  - `LockOverlay`: 他のアプリの上に重ねる全画面ウィンドウ。戻るキー無効、不透明度対応
  - `LockActivity`: 画面固定（screen pinning）でホーム・タスク管理を無効化する全画面画面
  - `MainActivity`: 手元で試すための入口画面

#### 💡 検討: ボタンを「追い出す」ことはできるか
- 戻るボタン → アプリで無効化できる（実装済み）
- ホーム／タスク管理ボタン → 普通のアプリでは無効化できない（Android の仕様）
- **見た目として隠す**（没入モード）はできるが、スワイプで戻せる
- **本当に無効化する**には画面固定（screen pinning）が要る。これは端末の初期化が不要で、Device Owner（キオスク）より手軽

#### 💡 決定: 2 方式を組み合わせる（弱点が互いに逆）
| 方式 | 強み | 弱点 |
|---|---|---|
| 画面固定 | ホーム・タスク管理を無効化 | 解除ジェスチャー（戻る＋タスク管理の長押し）で通常に戻れる |
| 重ね表示 | アプリを切り替えても一番上に残る | タスク管理の一覧画面だけは上に出る |
- **組み合わせ（full モード）**: 固定を解いても重ね表示が覆ったまま残るので、他のアプリに抜けられない。②でできる最強のロック
- ロックの強さ（overlay / pinning / full）は Device の項目にして、**管理者が管理画面から選べる**ようにする（脱獄ゲームの「抜け道を1つずつ塞ぐ」演出）
- **安全策**: テスト中に閉じ込められないよう、どのモードも一定時間（既定 30 秒）で自動解除するタイマーを入れた（時限ロックの機能にもなる）

#### 🐛 ハマり 3: WSL 上のプロジェクトを Android Studio が認識しない
- **症状**: `\\wsl.localhost\...` 上に作ったプロジェクトが Gradle として認識されず、ビルドできない
- **対処**: プロジェクトを Windows 側（`C:\Users\jiang\AndroidStudioProjects\ScreenJail`）に移した。発表用のソースはリポジトリの `android/` にコピーして記録する
- **学び**: WSL パス上の Android プロジェクトはこの症状が起きやすい。素直に Windows 側に置く

#### 🐛 ハマり 4: ビルドボタンが押せない（Gradle 同期の失敗）
- **症状**: ビルドボタンがグレーアウトして押せない
- **原因**: Android Studio がプロジェクトを開いた際、ビルドツールを勝手に新しすぎるバージョン（AGP 9.1.1 / Gradle 9.3.1）に上げていた。そのバージョンが端末に無く、同期が失敗していた
- **対処**: 端末にすでにある安定版（AGP 8.13.0 / Gradle 8.14）に戻した → コマンドラインでビルドが通り、APK 生成を確認
- **学び**: 「ビルドボタンが押せない」= だいたい Gradle 同期が未完か失敗。コマンドラインで `gradlew assembleDebug` を叩くと本当のエラーが見える。Studio の自動アップグレードの誘いは安易に受けない

#### ⚠️ 開発分担のメモ（発表で触れると良い）
- AI（Claude）が入口画面のコードを書く途中、安全フィルタに一度止められた。やり方を変えて書き直したら通った
- AI が書けない部分も、設計（CLAUDE.md）と動いている別ファイルを手がかりに進められた

### フェーズ 7: Rails とつなぐ（管理画面からロックする仕組み）
- **モデル**: `Device`（name, token, locked, opacity, lock_message, lock_mode, status, last_seen_at, connection_id, locked_at, escape_count, best_escape_seconds）と `DeviceEvent`
  - `lock_mode` を追加し、ロックの強さ（overlay / pinning / full）を管理者が選べるようにした
- **API**: `POST /api/devices`（端末登録。name を渡すと token を返す）
- **ActionCable**
  - `Connection`: token（`?token=` か `Authorization: Bearer`）から端末を特定。管理画面のブラウザは token なしでも接続できる（Turbo Streams 用）
  - `DeviceChannel`: 購読時に現在の状態を送る／3 秒ごとのハートビート／「覆いが出ているか」の報告／**自分の接続 ID が今の接続のときだけ offline**（講演の教訓）
- **管理画面** `/admin`（Basic 認証）: 端末カード、強さ選択、濃さ（不透明度）スライダー、文言、ロック・解除、全員ロック・解除、🏆 脱獄ランキング、ログ。更新は Turbo Streams でリアルタイム反映
- **ロック画面** `/lock?token=…`: token で端末を特定して描画（Android の WebView が開く）
- **死活判定** `DeviceStatusSweepJob`（5 秒ごと）: 15 秒で inactive、60 秒で offline。ロック中に offline になったら脱獄として記録
- **設計の核**: サーバーは「命令」ではなく `state`（locked / mode / opacity / message）を丸ごと送る。取りこぼしても再接続時の再送で追いつく。DB の `devices` が唯一の正

#### 🐛 ハマり 5: 管理画面が 204 No Content になる
- **症状**: `GET /admin` が 200 ではなく 204、ページが空
- **原因**: `index.html.erb` を `app/views/admin/` に置いたが、コントローラが `Admin::DevicesController` なので Rails は `app/views/admin/devices/index.html.erb` を探す → テンプレートが見つからず `head :no_content`
- **対処**: テンプレートを `admin/devices/` に移動 → 200 で表示
- **学び**: ログの「No template found for … rendering head :no_content」が決め手。名前空間付きコントローラのビューはフォルダ階層に注意

#### 🐛 ハマり 6: `uninitialized constant ApplicationCable::Channel`
- **症状**: broadcast やチャンネル読み込みで定数未定義エラー
- **原因**: `app/channels/application_cable/channel.rb`（基底クラス）が無かった
- **対処**: 基底クラスを作成 → 解消

- **確認**: 端末登録 → ロック（full / 濃さ80 / 文言）→ state 送信 → 脱獄記録 → 解除、まで runner で通ることを確認。Basic 認証（未認証 401 / 認証 200）、ロック画面 200 も確認

### フェーズ 8: Android をサーバーにつなぐ
- **CableClient**: OkHttp の WebSocket で Action Cable を話す最小クライアント
  - OkHttp はブラウザではないので Origin を送らない → **自分で `Origin` と `Authorization: Bearer <token>` を付ける**（講演の肝をコードで再現）
  - subscribe / message(perform) / 受信の振り分け / 指数バックオフ再接続
- **DeviceRegistrar**: `POST /api/devices` で端末登録し token を受け取る
- **LockService**（フォアグラウンドサービス, specialUse）: 接続を保ち、3 秒ごとにハートビート＋覆いの報告。届いた `state` を見て overlay / pinning / full を適用、解除なら閉じる
- **LockActivity**: サービスから解除できるよう静的参照を持たせ、URL を外から渡せるようにした。通信断でも戻れるよう保険の自動解除（180 秒）
- **MainActivity**: サーバー URL と名前で「参加」→ 登録 → サービス開始。通知権限の取得。手元テスト用ボタンも残す
- 権限追加: `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_SPECIAL_USE` / `POST_NOTIFICATIONS`
- **ビルド確認**: `gradlew assembleDebug` 成功（警告のみ）。実機での通し確認は次

---

## スクリーンショット・写真

`docs/screenshots/` に置き、ここからリンクする。発表で使えそうな場面:
- [ ] ロック画面のプレビュー（テーマ違い）
- [ ] 管理画面（デバイス一覧）
- [ ] 実機がロックされた瞬間
- [ ] 脱獄検知の 🚨
- [ ] 透け透けモード（不透明度 100% / 50%）

---

## 記録ルール（Claude と人間の両方が守る）

- 節目（フェーズの完了、方針の決定、ハマりの解決）ごとに、このファイルの「タイムライン」に追記する
- 決定は「何を選んだか」だけでなく「**なぜ**」と「**選ばなかった案**」を書く
- ハマりは **症状 → エラー文 → 原因 → 対処 → 学び** の順で書く
- 時刻はわかる範囲で書く（`date` で確認する）
- 発表で見せたい画面は `docs/screenshots/` に保存して、上のチェックリストにリンクする
