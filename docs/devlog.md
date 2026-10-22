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

### フェーズ 9: 実機で通し、ハマりを潰す
実機でつないでから、立て続けに問題が出た。どれも「実機＋ngrok＋オーバーレイ」ならではのもの。

#### 🐛 フォームの名前空間（強さ・文言・濃さが効かない）
- 管理フォームが `lock_mode` の名前で送っていたが、コントローラは `device[lock_mode]` で受けていた → `form_with scope: :device` で解決

#### 🐛 参加の重複登録 → ロックが届かない
- 「参加」を押すたびに新しい端末が作られ、古いカードにロックしても届かなかった
- 参加を冪等にし、`LockService` は**トークンが変わったら接続し直す**ように修正（古いトークンのまま繋ぎ続けていた）

#### 🐛 オーバーレイの WebView が真っ黒（文字が出ない）
- 症状: ロック画面が黒一色、文字なし。アクティビティ側の WebView は出る
- 原因①: `WindowManager` 直付けのウィンドウは既定で非ハードウェアアクセラレーション → WebView が描画されない。`FLAG_HARDWARE_ACCELERATED` を付与
- 原因②: 半透明オーバーレイ内で WebView に**不透明な黒**を敷くと合成がつぶれる → WebView は透明にし、暗い背景はコンテナに敷く
- 切り分け: 背景を一時的にマゼンタにして「WebView は描画できている／ページ読み込みの問題」を特定（教訓: 背景色を変えるだけで原因の層が分かる）

#### 🐛 CSS が当たらず白背景＋黒文字（これが本丸）
- 症状: ロック画面が素のまま（白背景・黒文字）。暗いオーバーレイでは文字が見えない
- 原因: **ngrok 無料プランの警告ページが、WebView の CSS/JS サブリクエストをブロック**していた。メインの document には `ngrok-skip-browser-warning` ヘッダーを付けていたが、そこから読む CSS には付かない
- 確認: `curl` で、ブラウザ UA かつヘッダー無しだと CSS の代わりに警告 HTML が返ることを確認
- 対処: WebView の **User-Agent を非ブラウザ名（`ScreenJail-Lock`）** にして全リクエストで警告を回避。加えて保険としてロックレイアウトに暗い背景＋明るい文字をインライン指定
- 学び: ngrok 経由で WebView を使うなら、サブリソースの警告回避（UA か全リクエストへのヘッダー付与）が要る

#### 🐛 ロックしていないのにオーバーレイが出続ける
- 原因: DB に `locked=true` の端末が残っていて、接続直後にサーバーが「ロック中」を送っていた（＝状態としては正しい動作）
- 対処: 残骸を掃除。show/hide に呼び出し元・理由のログを足し、状態と一致していることを logcat で確認

#### 🐛 環境まわり
- `bundle install` が権限エラー → ログインシェルが mise を読んでおらず、システム Ruby 3.2 を使っていた。`~/.bash_profile` から `.bashrc` を読むようにして解決
- WSL 上の Android プロジェクトを Studio が認識しない → Windows 側へ移動
- ビルドボタンが押せない → Studio が AGP/Gradle を新しすぎる版に上げていた。安定版に固定

### フェーズ 10: 休憩リクエスト（ロック画面から「休憩したい」を送る）
通し動作が安定したので、遊びの幅を広げる機能に着手。利用者がロック画面から「休憩したい／トイレ／その他」を送り、管理者が承認して一時的に解除する流れを作る（承認 UI と再ロックはこの先）。

#### データ化（まず文言とボタンをデータにした）
- `lock_title` と `lock_buttons`（最大 2 個, `{label, kind}`）を Device のデータに。`lock_screen_data` を HTML 描画と `/lock.json` で共通に使う
- ねらい: iOS（将来の Screen Time）など別の描き手が出てきても、同じデータから画面を作れるようにしておく

#### 💡 決定: トークンを URL に残さない（Cookie に移す）
- これまで `/lock?token=…` を開きっぱなしだった。URL にトークンが残ると、履歴・ログ・肩越しの覗き見で漏れ、`ANDROID_ID` 等を知る第三者がなりすませる
- 対処: **初回だけ** `?token=` を受け取り、署名付き Cookie（`httponly`、`secure` は本番のみ）を発行して、トークン無しの `/lock` にリダイレクトする。以降の表示と送信は Cookie で端末を特定し、**Rails 標準の CSRF 対策**を使う。`/lock.json` は `Authorization: Bearer` に切り替え
- 選ばなかった案: トークンを URL に持ち続ける（漏えいが怖い）／送信も Bearer の API にする（ブラウザ由来の CSRF・Cookie の扱いを学べなくなる。講演の「相手はブラウザだけじゃない」を両面で見たい）
- Android: Cookie を保持するため `CookieManager` を明示的に有効化（overlay・activity 両方）

#### 💡 決定: 状態反映は Turbo Streams（ポーリングも全体リロードもしない）
- 承認待ち → 承認 → 解除、の変化をロック画面に映すのに、以前「ポーリングで良いのでは」と迷った。だが WebView 全体のリロードは**ちらつき**と再接続コストがあり、ポーリングは無駄が多い
- 対処: 端末ごとのストリーム（`turbo_stream_from device, :lock`）を購読し、`#lock_request_zone` だけを差し替える。送信後も画面は再読込しない
- 講演の「Turbo と raw Cable の使い分け」をそのまま応用：**画面更新は Turbo Streams、端末のロック状態同期は raw Cable（DeviceChannel）**

#### 💡 決定: 連打対策はサーバー側
- 画面のボタン無効化だけだと、ネットワーク競合や細工で抜けられる
- 二段で守る: ①モデル検証「1 端末につき未処理（open）は 1 件だけ」 ②`rate_limit`（端末ごと 10 秒に 2 回まで）。取り消し（cancelled）もできるようにした
- 期限切れ: 作成時に `set(wait_until: expires_at)` で `ExpireBreakRequestJob` を予約して pending→expired。`open` スコープは時刻で判定するので、ジョブが遅れても画面表示は正しい（ジョブは後片付け）

#### 🐛 テスト基盤を新設。rate_limit のストアがテスト間で漏れた
- `rails new --skip-test` で作っていたので `test/` が無い。今回 minitest を足し、モデル検証と送信まわり（1 件制限・連打・期限切れ・他端末のものに触れない・Cookie 発行とリダイレクト）を書いた
- 症状: 1 回しか送っていないテストまで `429 Too Many Requests` になる
- 原因: `rate_limit` の `MemoryStore` がプロセス内で共有され、かつトランザクションのロールバックで端末 ID（1, 2…）が毎テスト再利用される → 前のテストのカウントが次へ漏れていた
- 対処: `setup` でストアを `clear`。テスト DB は `--skip-test` でも `test.rb` が CSRF を無効化しているのでリクエストテストは素直に書けた
- 学び: プロセス内キャッシュを使う機能はテスト間の状態リークに注意。キーに使う ID がロールバックで再利用されることも合わせて踏む

#### 🔧 補強（レビューで挙がった 4 点）
実機で通ったあと、Phase 2 の作りを 4 点見直して固めた。
- **Cable の Cookie 認証**: Cable 接続の端末識別を token/Bearer だけでなく**署名付き Cookie** にも対応（WebView の Turbo 接続は Cookie を送るため）。識別ロジックは `Device.from_lock_cookie` に集約し、HTTP と Cable で共有
- **rate_limit の保存先**: テスト用に置いていたプロセス内 `MemoryStore` 定数は、本番の複数プロセスで共有されない。アプリのキャッシュ（本番は `solid_cache` ＝共有）を使うよう変更し、テストだけ `memory_store` に（null_store だと数えられない）
- **部分ユニークインデックス**: 「1 端末 1 件」をモデル検証だけに頼らず、`where status='pending'` の**部分ユニークインデックス**で DB レベルに保証。作成前に期限切れ pending を expired へ掃除して整合させ、競合時は `RecordNotUnique` を 422 に変換
- **Cookie のトークン世代**: 署名付き Cookie に `token_generation` を埋め、`rotate_token!`（将来の ANDROID_ID 再登録で使う）で token を回したら**古い Cookie を無効化**できるようにした
- ハマり: `ActionCable::Connection::TestCase` は署名 Cookie を接続のリクエストに載せない（`request.cookies` が nil）。Cookie 経路の中核は `Device.from_lock_cookie` の単体テストと HTTP 統合テストで担保し、コネクションテストは token と nil に絞った

### フェーズ 11: 承認 UI（休憩リクエストを管理者が承認・却下）
管理者が承認待ちリクエストを承認／却下し、承認したら端末を一時的に解除する。

#### 💡 決定: 承認は「フェーズ4の核だけ前倒し」＝実効ロック
- 承認で `locked` は変えず、**`unlock_until = 現在時刻 + 分数`** を記録する
- 端末に送る状態 `state_payload[:locked]` は**実効ロック**＝`locked かつ（unlock_until が nil または過去）`で計算
- `unlock_until` の時刻に状態を送り直す予約ジョブ **`RelockDeviceJob.set(wait_until:)`** → 期限が過ぎれば実効ロック=true に戻り、**自動再ロック**まで動く
- ジョブは「今の状態を送り直すだけ」。延長で期限が先に伸びていても、解除状態を送るだけで無害（新しい時刻に別ジョブが入る）。**延長・手動再ロックの UI、取りこぼし用スイープはフェーズ4**に残す
- 手動 `lock!` / `unlock!` は `unlock_until` を消す（手動操作を一時解除より優先）
- なぜこの形か: 「命令ではなく状態を送る」という方針（講演の The rule）と相性が良い。サーバーは常に“今ロックすべきか”だけを送り、端末はそれに従う。解除の残り時間の判定もサーバー時刻が正
- 再ロックジョブは**発火時に今の `unlock_until` で実効ロックを計算し直して送る**だけ（強制ロックしない）。これでフェーズ4の延長を入れても、延長前の時刻に古いジョブが発火するとまだ解除状態を送るだけで、延長が無視されない
- **脱獄判定は実効ロックで行う**。一時解除中（`unlock_until` が未来）は `locked` が true のままでも、オフライン・アプリ終了を脱獄に数えない（正当に使える時間なので）。`mark_escaped!` / `DeviceChannel` / 死活 sweep をすべて `effective_locked?` 基準に統一
- full モードで承認されると状態 locked=false が届き、`LockService.releaseLock` → `LockActivity.releaseIfRunning`（`stopLockTask` で画面固定解除）＋オーバーレイ非表示で、**画面固定も解ける**

#### 承認・却下の操作
- 承認: プリセット **5/10/15/30 分**、kind ごとの既定（toilet=5 / break=10 / その他=10）を初期選択。プリセット外は既定に丸める。任意で一言返信
- 却下: 返信（理由）つき
- 反映は **Turbo Streams**。`BreakRequest` の変更で、端末のロック画面（`#lock_request_zone`）と管理画面（その端末のカード）の**両方**を差し替える。ポーリングも全体リロードもしない

#### 管理 UI
- カードに「承認待ちリクエスト」「一時解除の残り時間」「承認／却下フォーム」を追加
- 「全員操作」で `lock_title` と `lock_buttons`（プリセット: 休憩+トイレ / 休憩+その他 / トイレのみ / なし）を一括設定。文言・ボタンの変更は `device_facing_change?` に載せ、端末にも反映されるようにした
- iPhone Safari 向けに狭幅（≤480px）の media query（1 カラム、タップ領域 40px）

#### テスト
- `Device`（実効ロック・残り時間・grant/手動ロックの打ち消し）、`BreakRequest`（承認・却下・既定分数・プリセット丸め）、管理コントローラ（承認で一時解除・却下・認証必須・一括設定）、`RelockDeviceJob`（状態再送）

### フェーズ 12: 実機テストで出た不具合をまとめて潰す
承認 UI まで実機で通したら、NG が複数出た。原因をログと生成 HTML で特定してから直した。

#### 🐛 脱獄回数が3秒おきに増え続ける（885回）
- 症状: ログに「脱獄」が**ちょうど3秒おき**＝ハートビート間隔で記録され、`escape_count` が膨張
- 原因①: **`DeviceChannel#current_device` が接続時に一度読まれたきりで古い**。`report`（3秒おき）が古い状態で脱獄判定していた
- 原因②: **脱獄に「1回だけ数える」仕組みが無かった**。同じ「逃げている」状態で report が来るたびに数え直していた
- 対処: `report`/`unsubscribed` で `reload` して最新状態で判定。`escaped` フラグを追加し、**「ロック中→逃げた」の状態変化 1 回につき 1 回だけ**数える。覆いが戻ったら `mark_recaptured!` で `escaped` を戻す。`lock!`/`unlock!` でも `escaped` をリセット
- 学び: 長命な ActionCable 接続では `current_device` は古くなる。状態判定の前に読み直す。回数は「状態変化」で数える（イベントの到着回数で数えない）
- この洪水（3秒おきに大量 broadcast）が管理画面の表示崩れ（📨 が出ない／残り時間が出ない／脱獄回数が消える）も招いていた。生成 HTML を確認して `<details>`・`<form>` の閉じ忘れが無いことは確認済みで、崩れの主因はこの洪水だった

#### 🐛 再インストールで別端末になる（重複カード）
- 症状: 同じスマホが、再インストールのたびに別カードとして増える（同名で online 885回と offline 0回が併存）
- 対処: 登録 API に **`client_id`（ANDROID_ID）** を渡し、同じ `client_id` は同じ行を再利用。再登録時は **token を作り直す**（古い token・Cookie を無効化＝なりすまし対策）。カードに**端末 ID（短縮）**を表示して見分けられるようにした

#### 承認待ちに気づく手段（通知の前の最低限）
- 画面上部に「🔔 承認待ち N 件」バナー（Turbo Streams でリアルタイム更新）
- タブのタイトルに件数（例: `(1) ScreenJail 管理`）。Stimulus の `pending` コントローラが受け持つ
- 新着時に短い音（WebAudio）。※ iOS Safari は一度画面を触るまで鳴らないことがある

#### 調査メモ（計測の落とし穴）
- トランザクションテストでは `after_commit` がテスト中に発火しないため、`capture_broadcasts` が 0 件になる。broadcast の中身は「`after_commit` を介さず partial を直接描画」して確認した
- Turbo の broadcast ストリーム名は `turbo:streams:admin` のように接頭辞が付く（生の `"admin"` ではない）

### フェーズ 13: 管理画面を Turbo 8 のページリフレッシュ（morph）に切り替え
ログ解析で、管理画面のライブ更新が効かない原因が 2 つ判明した。
- **新規端末のカードが出ない**: 新規登録時の配信が `replace target="device_20"`。登録前に開いていた管理画面には `device_20` が無く、Turbo は何もしない（append が必要だった）
- **休憩リクエストが出ない**: 作成時の admin への配信が、個別 target への replace で、対象や並びの前提に依存して届かない場面があった

#### 💡 決定: 個別の replace/append をやめ、ページリフレッシュ（morph）配信に統一
- 管理レイアウトに `turbo_refreshes_with method: :morph, scroll: :preserve`
- `Device` / `BreakRequest` / `DeviceEvent` は、変更時に `broadcast_refresh_to "admin"` を配信（`after_commit`）。購読側は現在の URL を取り直して **morph で差分だけ当てる**
- 一覧・バナー・ランキング・ログがすべて「今の DB の状態」で描き直るので、**新規カードも承認待ちも残り時間も、取りこぼしなく**反映される
- なぜ `broadcasts_refreshes_to`（`_later`＝デバウンス＋ジョブ）ではなく即時 `broadcast_refresh_to` か: 即時配信は同期的でテストが安定する。morph の重複当ては Turbo クライアント側で吸収される。件数が少ないハッカソン規模では十分
- **端末のロック画面は従来どおり個別差し替え**（`#lock_request_zone` のみ）。全面リフレッシュのちらつきを避ける
- 入力の保護: 却下理由・一括設定のタイトル/選択・端末の文言の `<input>` に `data-turbo-permanent` と安定した id を付け、morph で入力中のテキスト・フォーカスが消えないようにした
- 承認待ちバナーは morph で `data-pending-count-value` が変わり、Stimulus の `countValueChanged` でタブのタイトルと新着音（件数が増えたときだけ）を更新する

#### テスト
- 端末の新規登録・休憩リクエストの作成/承認/却下/取り消しで `"admin"` に refresh が配信されることを統合テストで確認（`after_commit` を発火させるためこのクラスだけ非トランザクション）

#### 🔧 見た目に関わる変更のときだけ配信する
- 指摘: `after_commit` が全コミットで発火すると、ハートビートの `last_seen_at` 更新などでも管理画面が全体を取り直してしまう（端末数 × 3 秒）
- 実態: ハートビートは `update_columns`（コールバックを飛ばす）なので元々配信されないが、作りとして危ういので明示的にガードした
- 対処: `ADMIN_VISIBLE_COLUMNS`（name/status/locked/lock_mode/opacity/lock_message/lock_title/lock_buttons/unlock_until/escape_count/best_escape_seconds/client_id）**が変わったとき＋削除のときだけ** `broadcast_refresh_to "admin"` を配信。`last_seen_at`・`connection_id` だけの更新では配信しない
- デバウンス: morph の重複当ては **Turbo クライアント側が coalesce** する（全員ロックなどで複数端末が一度に変わっても、実際のページ取得はまとまる）。サーバー側でまとめたい場合は `broadcast_refresh_later_to`（request_id 単位のデバウンス）に替えられるが、同期テストがしにくいため今は即時配信のまま

### フェーズ 14: 時限ロックの仕上げと運用まわり（フェーズ4・サーバー側）
サブフェーズごとに実装→テスト→コミット。管理者レビュー（reviewer サブエージェント）を通してから報告する運用に切り替えた。

- **4e 本番の管理者認証ガード**: 本番で `ADMIN_USER`/`ADMIN_PASSWORD` 未設定なら**起動時にエラー**（既定値にフォールバックしない）。開発・テストは `admin`/`admin`。`fetch_admin_credential` に切り出してテスト可能に
- **4b 再接続時の取りこぼし防止**: `DeviceChannel#subscribed` が購読直後に現在の状態を transmit することをチャンネルテストで固定（切断中に変わった状態も再購読で追いつく）
- **4d 再ロックの取りこぼしスイープ**: 予約ジョブが失われても拾えるよう `RelockSweepJob`（15秒毎）を追加。`RelockDeviceJob` は「期限切れなら `unlock_until` を消して確定／延長中なら状態を送るだけ」に整理 ＝ grant 時の予約・延長時の再予約・スイープの三層
- **4c 延長・手動再ロック**: 管理カードに「+5分／+10分／今すぐ再ロック」。延長は残り時間に足して再ロックジョブを予約し直す。手動再ロックは `unlock_until` を消すだけ（locked・escaped・locked_at はそのまま＝同一ロックセッションの再開）
- **4a ハートビート 30 秒化**: 3秒→30秒で電池・通信量を削減。死活しきい値を `INACTIVE_AFTER=45`／`OFFLINE_AFTER=90`、sweep を 15 秒に合わせた（取りこぼし1〜3回を見込む）。※Android 再ビルド要

#### レビュー運用の導入
- CLAUDE.md に「選択肢の提示前・フェーズ完了報告前・コミット前に reviewer サブエージェントへ計画・差分・テスト結果を渡して判定をもらう」を追加（`.claude/agents/reviewer.md`）。報告には判定・条件・人間が確認すべきことをそのまま載せる

#### 🐛（切り分け）「機内モードで脱獄が検知されない」→ 実データで正常と判明
- 症状報告: 機内モードにしても脱獄が検知されない
- 調べ方: sweep が実際に動いているか（Solid Queue の RecurringExecution、実行15404回）と、開発DBの `device_events` を直接確認
- 判明: ロック中のオフラインでは `escaped` が記録されていた（検知は機能）。報告時に近いオフラインは、その時間帯に端末が「解除」状態だったため正しく非カウント。再ロック後は端末が online のままで、ロック中に機内モード→90秒待ちが実行されていなかった
- 結論: ロジックのバグではなく検証条件の問題。`device_status_sweep_job_test` でロック中offline→脱獄1回／解除中offline→0回を固定済み
- 可視化の改善: 「検知されたか」が管理画面で分かりにくかったので、カードに **「🚨 脱獄中」バッジ**を追加（`escaped` を見た目の列に加え、連れ戻し・承認で消える）
- 整合性の修正: **承認（`grant_break!`）時に `escaped` をクリア**。脱獄中に休憩を承認したとき「⏳一時解除中」と「🚨脱獄中」が同時に出ないようにした（`escaped=true` のまま `effective_locked?=false` になる唯一の抜けを塞いだ）
- 学び: 「直っていない」の報告は、まず**実データ（イベントログ・DB）とジョブ実行記録**で、ロジックの問題か検証条件の問題かを切り分ける

#### 🐛 連れ戻しが同じ秒に2回 ＝ 同時接続の競合（check-then-act）
- 症状: 実機ログで `recaptured` が同じ秒に2回。集計すると recaptured 5 > escaped 4
- 原因: full モードは同じ端末へ複数経路（LockService・アクティビティ・オーバーレイ）で接続する。各経路が同時に「復帰」を報告し、`mark_recaptured!` が **`escaped` を読んでから書く**ため、2つが両方 true を読んでから両方書いて二重記録。脱獄カウントでも同じ競合が起きうる
- 対処: `mark_escaped!`/`mark_recaptured!` を**条件付きの原子的1回更新**に変更。`where(id:, escaped: false).update_all("escape_count = escape_count + 1, escaped = true …")` の**更新件数が1のときだけ**イベント記録・配信する。SQLite の書き込み直列化で先勝ちの1件だけが当たる
- テスト: **スレッド2本の同時実行**で「同時報告でも記録は1回」を固定（別コネクションが実データを見られるよう非トランザクション）
- 学び（レビューにも反映）: **同時接続からの二重処理は、順番どおりのテストでは絶対に出ない。** reviewer はこれを一度見逃した → reviewer の観点に「同時実行・競合（check-then-act）」を追加し、該当時はスレッドテストを要求するようにした
- 横展開の宿題: 同型の check-then-act が `BreakRequest#approve!/deny!/cancel!` などにも残る（同時承認で二重 grant）。別タスクとして対応予定

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
