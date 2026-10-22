# CLAUDE.md — ScreenJail（仮）

楽しむための 4 時間ハッカソン。審査はない。
**管理者が Rails の管理画面から、参加者の Android スマホを全画面のロック画面で覆って「使えなく」する。
ロックされた人は抜け道を探して脱獄を試み、管理者はそれを検知して塞いでいく ── 「脱獄ゲーム」として遊ぶ。**

完璧さより「早く動く → 遊べる → 足す」を優先する。

背景知識は `docs/kaigi-on-rails-2026/notes.md`。特に yujiteshima さんの
「ActionCableの相手はブラウザだけじゃない」（Origin、half-open、ハートビート、Turbo と raw Cable の使い分け）をこのアプリで再現・応用する。

---

## ディレクトリ構成

```
.
├── CLAUDE.md
├── server/     # Rails 8 アプリ（管理画面、API、ActionCable）
├── android/    # Kotlin アプリ（ロック画面のオーバーレイ）
└── docs/
    ├── devlog.md      # 開発ログ（発表用）。節目ごとに追記する
    ├── screenshots/   # 発表で使う画面のスクショ・写真
    └── kaigi-on-rails-2026/
        ├── notes.md   # Kaigi on Rails 2026 のまとめ
        └── raw/       # 元の聴講メモとスライド写真（参照用。編集しない）
```

`server/` はセットアップ済み（起動・Origin チェック・Solid Queue の動作を確認済み）。`android/` はまだ作っていない。

---

## UI の方針（後から自由に変えられるようにする）

**ロック画面の見た目は Rails 側で描画し、Android アプリはそれを WebView で表示するだけにする。**
ロック画面のデザイン、文言、DHH 名言、カウントダウン、クイズなどは Rails のビューを変えるだけで反映され、Android アプリのビルドし直しは要らない。
Android ネイティブ側が受け持つのは「全画面で覆う」「戻るを無効にする」「不透明度」「状態の同期」だけ。

Rails のビューと CSS は次のルールで作る。
- **デザイントークン**: 色・文字サイズ・余白・角丸は `app/assets/stylesheets/tokens.css` の CSS 変数だけで定義する。ほかの CSS に色の値を直接書かない
- **テーマ**: `<html data-theme="…">` で切り替える。テーマを足すときは `tokens.css` にブロックを 1 つ追加し、`LockPreviewsController::THEMES` に名前を足す（今は `jail` と `kaigi`）
- **CSS ファイルの役割**: `tokens`（値）→ `base`（リセット）→ `components`（共通部品: `.card` `.button` `.badge` `.stack` `.cluster`）→ 画面別（`admin` / `lock`）。レイアウトごとに `stylesheet_link_tag` で読み込むファイルを明示している
- **レイアウト**: 管理画面は `layouts/admin`、ロック画面は `layouts/lock`。共通の `<head>` は `layouts/_head`
- **ロック画面はスロットの組み合わせ**: `lock/_screen` が全体の構成で、`lock/_title` `lock/_message` `lock/_footer` などの partial を並べる。要素の追加・並べ替え・差し替えは `_screen` で行う
- **プレビュー**: `GET /lock_preview?theme=jail` で、ロック画面の見た目をブラウザで確認できる（PC でも可）
- クラス名は役割で付ける（`.lock-message` は可、`.big-pink-text` は不可）

---

## ロックの仕組み（採用案：全画面オーバーレイ）

Android アプリが「他のアプリの上に重ねて表示」権限（`SYSTEM_ALERT_WINDOW`）を使い、
`TYPE_APPLICATION_OVERLAY` のウィンドウで画面全体を覆う。

| 操作 | 結果 | 実装メモ |
|---|---|---|
| 画面タッチ | 下のアプリに届かない | オーバーレイはタッチを受け取る設定にする（`FLAG_NOT_TOUCHABLE` を付けない） |
| 戻る | 無効 | オーバーレイをフォーカス可能にして（`FLAG_NOT_FOCUSABLE` を付けない）、`dispatchKeyEvent` で `KEYCODE_BACK` を握りつぶす |
| ホーム／アプリ切り替え | 押せるが、ロック画面は残る | アプリからは止められない。オーバーレイは全アプリの上に残る |
| 電源ボタン | ロック画面は残る | |
| 通知バー・クイック設定 | **開ける（抜け道）** | OS の仕様で止められない → 脱獄ルートとして扱う |
| 機内モード | **できる（抜け道）** | サーバーから見るとハートビートが途絶える → 脱獄として検知 |
| 実行中アプリからの停止（Android 13+） | **できる（抜け道）** | 同上 |
| 再起動 | 一度消える | `BOOT_COMPLETED` で自動ロックし直す（+α） |

### 透け透けモード（不透明度）
- 管理者がスライダーで不透明度 0〜100% を変えられる。`WindowManager.LayoutParams.alpha` に反映する
- **Android 12 以降では、他アプリのオーバーレイの不透明度が 80% を超えると、下のアプリにタッチが届かない**（タップジャッキング対策）。
  80% 以下でタッチを通す「ゆるいロック」にするなら `FLAG_NOT_TOUCHABLE` を付ける
- 仕様案: 100% = 完全ロック / 50% = 透けて見えるが操作できない（タッチは受け取る） / 0% = 実質解放
- 機種差があるので、実機で最初に確認する項目に入れる

### 割り切り
- 本物の OS ロック（Device Owner + Lock Task Mode）は端末の初期化が必要なので採用しない
- 対象は Android のみ。iPhone は対象外
- 参加者本人が同意した端末だけで使う

---

## 技術スタック

### server/（Rails）
- Ruby 3.4.5 / Rails 8.0.5.1 / SQLite
- **json gem は `~> 2.10` に固定している**（json 3.x で `quirks_mode` が削除され、Rails 8.0 の ActiveSupport::JSON が壊れるため。外さないこと）
- Hotwire（Turbo Streams + Stimulus）、importmap（Node のビルドは不要）
- **開発環境でも Solid Cable + Solid Queue を使う**（理由は後述）。Redis は使わない
- 管理画面は `http_basic_authenticate_with`（ENV `ADMIN_USER` / `ADMIN_PASSWORD`、未設定時は `admin` / `admin`）
- Android 向けの API は `ActionController::API` を継承した `Api::BaseController` 配下に置き、デバイストークンで認証する
- CSS は手書き。凝らない

### android/（Kotlin）
- Kotlin、minSdk 26、targetSdk 35
- OkHttp の WebSocket で ActionCable に直接接続する（ActionCable のクライアントライブラリは使わない）
- JSON は `org.json`（標準）で十分
- 主なクラス:
  - `MainActivity`: サーバー URL と名前を入力して登録、オーバーレイ権限と通知権限の取得、サービス開始
  - `LockService`: フォアグラウンドサービス（`specialUse`）。WebSocket の接続維持、ハートビート、オーバーレイの表示・非表示
  - `LockOverlay`: 全画面のオーバーレイ。中身は **WebView で Rails の `/lock` を表示**する。戻るキーの無効化と不透明度はネイティブ側で行う
  - `CableClient`: ActionCable プロトコルの最小実装（subscribe / perform / 受信 / 再接続）
  - `BootReceiver`（+α）: 再起動後にサービスを起動し直す
- 権限: `INTERNET`, `SYSTEM_ALERT_WINDOW`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED`
- ロック状態（locked / opacity / message）は `SharedPreferences` にも保存する。オフラインや再起動のあともロックを続けるため

---

## セットアップ

### server/（作成済み）
```bash
cd server
bin/rails db:prepare
bin/dev            # 0.0.0.0:3000 で起動。SOLID_QUEUE_IN_PUMA=1 で Solid Queue も同じプロセスから起動する
# 別ターミナル
ngrok http 3000    # → https://precision-map-wildness.ngrok-free.dev（アカウント固定のドメイン。毎回同じ）
```

- **ERR_NGROK_3200（エンドポイントはオフライン）** が出たら、ngrok のプロセスが止まっている。`ngrok http 3000` を起動し直す
- 無料プランの ngrok は、ブラウザでの初回アクセス時に警告ページを挟む。**Android の WebView / OkHttp のリクエストには `ngrok-skip-browser-warning: 1` ヘッダーを付ける**

- 動作確認用ページ: `/`（トップ）、`/lock_preview?theme=jail`、`/up`
- `rails new` は `--skip-git --skip-kamal --skip-thruster --skip-test --skip-system-test --skip-jbuilder` で作成。CSS フレームワークは使っていない（Propshaft + 手書き CSS）

**開発環境で Solid Cable / Solid Queue を使う理由**: Rails 8.0 の開発環境の既定は Cable も Job も async（プロセス内）。
死活判定の recurring job は Solid Queue でしか動かず、Solid Queue のワーカーは別プロセスで動くため、
ジョブからの broadcast をクライアントに届けるには Cable も Solid Cable（DB 経由）にする必要がある。設定済みの箇所:
- `config/database.yml`: development に `queue` と `cable` の SQLite DB（`storage/development_{queue,cable}.sqlite3`）
- `config/cable.yml`: development を `solid_cable` に
- `config/environments/development.rb`: `queue_adapter = :solid_queue`、ngrok のホスト許可、ActionCable の許可 Origin
- `bin/dev`: `SOLID_QUEUE_IN_PUMA=1` を設定して Puma の plugin で Solid Queue を起動

**Origin チェックの確認結果**: ngrok の Origin → 101（接続 OK）、ほかのドメイン → 拒否、Origin なし → 拒否。
Android アプリは Origin を送らないので、自分で `Origin` ヘッダーを付けないと拒否される（講演と同じ現象）。

### android/
- Windows の Android Studio で `android/` を新規プロジェクト（Empty Views Activity、Kotlin、パッケージ名 `com.example.screenjail`）として作る。
  場所は `\\wsl.localhost\Ubuntu\home\tigarashi\workspace\RAILS\RocHackatho\android`
- コードの編集は Claude が行い、**ビルドと実機へのインストールはユーザーが Android Studio で行う**
- adb は Windows 側の `adb.exe` を使う（`/mnt/c/Users/jiang/AppData/Local/Android/Sdk/platform-tools/adb.exe`）。WSL の `adb` からは USB 接続の端末が見えない
- 端末側: 開発者向けオプション → USB デバッグを ON。アプリ初回起動時に「他のアプリの上に重ねて表示」を許可する

---

## server/ の設計

### 画面と URL

| URL | 誰が | 内容 |
|---|---|---|
| `GET /admin` | 管理者 | デバイスのカード一覧、全員ロック・全員解除、脱獄ランキング、イベントログ |
| `PATCH /admin/devices/:id` | 管理者 | `locked`, `opacity`, `lock_message` を更新（ボタンとスライダーから） |
| `POST /admin/lock_all` `/admin/unlock_all` | 管理者 | 一斉ロック・解除 |
| `GET /lock` | Android（WebView） | ロック画面。`Authorization: Bearer <token>` でデバイスを特定し、`lock/_screen` を描画する |
| `GET /lock_preview?theme=…` | 開発者 | ロック画面の見た目の確認用（作成済み） |
| `POST /api/devices` | Android | `{name}` → `{id, token}` を返す（端末登録） |
| `/cable` | Android・管理画面 | ActionCable |

### データモデル

```
Device
  name            :string   null: false
  token           :string   null: false, index unique   # has_secure_token
  locked          :boolean  default: false, null: false
  opacity         :integer  default: 100, null: false   # 0..100
  lock_message    :string
  status          :string   default: "offline"           # online / inactive / offline
  last_seen_at    :datetime
  connection_id   :string                                # 現在の Cable 接続の ID
  locked_at       :datetime                              # 今回のロック開始時刻
  escape_count    :integer  default: 0, null: false
  best_escape_seconds :integer                           # 最速脱獄タイム

DeviceEvent
  device:references
  kind            :string   # lock / unlock / opacity / online / inactive / offline / escaped / recaptured
  payload         :json
  created_at
```

### 通信の方針（講演の「The rule」に従う）

| 種類 | 方向 | 方式 |
|---|---|---|
| ロック状態の同期 | サーバー → Android | `DeviceChannel` で JSON を送る |
| ハートビート | Android → サーバー | `DeviceChannel#heartbeat`（3 秒ごと） |
| 管理画面の更新（カード、ランキング、ログ） | サーバー → 管理画面 | **Turbo Streams**（`broadcast_replace_to "admin"` / `broadcast_prepend_to "admin"`） |
| （+α）加速度の波形 | Android → 管理画面 | raw ActionCable + canvas。Turbo は使わない |

**命令ではなく状態を送る。** サーバーは常に `{type: "state", locked:, opacity:, message:}` の形で現在の状態をまるごと送り、
Android はそれをそのまま画面に反映する。取りこぼしても次のメッセージや再接続で追いつく。DB の `devices` が唯一の正。

### ActionCable と Android の接続（講演の教訓を反映）

- **Origin**: OkHttp は Origin ヘッダーを送らないので、そのままだと ActionCable に拒否される。
  **Origin チェックは無効にしない。** Android 側で `Origin: <サーバーの URL>` を明示的に付けて接続する
- **認証**: `ApplicationCable::Connection` で、`Authorization: Bearer <token>` ヘッダーからデバイスを特定する。
  管理画面からの接続は Basic 認証済みのセッションで識別する。どちらでもなければ `reject_unauthorized_connection`
- ActionCable のプロトコル（Android の `CableClient` で実装する）:
  - 購読: `{"command":"subscribe","identifier":"{\"channel\":\"DeviceChannel\"}"}`
  - 送信: `{"command":"message","identifier":"…","data":"{\"action\":\"heartbeat\"}"}`
  - 受信: `welcome` / `ping`（3 秒ごと）/ `confirm_subscription` / `{"identifier":…, "message":{…}}`
  - 切断されたら 1 秒、2 秒、4 秒…と待って再接続する（最大 10 秒）

### DeviceChannel
- `subscribed`: `stream_for device`。`connection_id` を新しい値で上書きし、`online` にする。直後に現在の状態を送る
- `heartbeat`: `last_seen_at` を更新する。`inactive` / `offline` から戻ったら `online` にする
- `report(overlay_shown:)`: Android 側でオーバーレイが実際に表示されているかを報告する。サーバーはロック中なのに `false` なら脱獄とみなす
- `unsubscribed`: **自分の `connection_id` が `device.connection_id` と一致するときだけ** offline にする
  （再接続のあとに古い接続が閉じて、新しい接続を offline にしてしまう問題への対策）

### 死活判定と脱獄判定
- `DeviceStatusSweepJob`（`config/recurring.yml` で 5 秒ごと）
  - `last_seen_at` が 15 秒より前なら `inactive`、60 秒より前なら `offline`
  - 状態が変わったときだけ更新する（無駄な broadcast を出さない）
- **脱獄** = ロック中に次のどれかが起きたとき
  - `inactive` になった（機内モードやアプリの停止。通信が途絶えた）
  - `report(overlay_shown: false)` を受け取った（再起動直後など）
- 脱獄したら `escaped` イベントを記録し、`escape_count += 1`。`locked_at` からの経過秒で `best_escape_seconds` を更新する。管理画面に 🚨 を出す
- ロック中のまま再接続して、オーバーレイが表示されたら `recaptured`（連れ戻し）

---

## 4 時間の進め方

| 時間 | ゴール | 完了の条件 |
|---|---|---|
| 0:00–0:30 | server/ と android/ を作る。ngrok を起動する | スマホのブラウザで ngrok の URL が開ける。空のアプリを実機にインストールできる |
| 0:30–1:15 | **Android 単体でロック画面を出す**（アプリ内のボタンで表示・非表示） | 戻るが効かない。タッチが下に届かない。不透明度を変えるとどうなるかを実機で確認する |
| 0:30–1:15 | （並行）Rails の Device、API、DeviceChannel、管理画面 | ブラウザの管理画面でロックボタンを押すと DB が更新される |
| 1:15–2:00 | **つなぐ**: Android → ActionCable → 管理画面から実機をロック・解除 | 管理画面のボタンで実機にロック画面が出る・消える |
| 2:00–2:45 | ハートビート、死活判定、脱獄検知、SharedPreferences への保存、不透明度スライダー | 機内モードにすると管理画面に 🚨。戻すとロックしたまま復帰する |
| 2:45–3:30 | 面白要素を 1〜2 個（下のリスト） | |
| 3:30–4:00 | デモの準備、バッファ | |

**つなぐところまで動くまで、面白要素には手を出さない。**

## 面白要素

**コア（必ずやる）**
- 🚨 **脱獄ゲーム**: 脱獄すると管理画面に通知され、脱獄タイムでランキングする
- 👻 **透け透けモード**: 管理者が不透明度スライダーでロックの「濃さ」を変える

**+α（好きなものを選ぶ）**
- 💬 **DHH 名言ロック**: ロック画面に `docs/kaigi-on-rails-2026/notes.md` の名言をランダムに表示
- 🎰 **ロックガチャ**: 管理画面のルーレットで当たった人だけロック
- ⏱ **時限ロック**: カウントダウンを表示し、0 で自動解除（`UnlockJob.set(wait:)`）
- 📳 **振って脱出**: 50 回振ったら解除。加速度の波形を管理画面の canvas に表示（raw Cable）
- 🤝 **仲間に救出してもらう**: ほかの参加者が管理画面の「解放」ボタンを合計 100 回押すと解除
- 🔁 **再起動対策**: `BootReceiver` で自動的にロックし直す（管理者が抜け道を塞ぐ演出）
- 🔊 ロックした瞬間にバイブと効果音

---

## Claude への作業ルール

- **開発の流れは後で発表する。節目（フェーズの完了、方針の決定、ハマりの解決）ごとに `docs/devlog.md` に追記する。**
  書き方は devlog 末尾の「記録ルール」に従う（決定は理由と不採用案も、ハマりは症状 → エラー → 原因 → 対処 → 学び）
- 発表で見せたい画面ができたら、スクリーンショットを撮って `docs/screenshots/` に保存するよう人間に提案する

- 返答とコメントは日本語。コードの識別子は英語
- Rails は標準（generator、規約、Hotwire）を優先する。gem を増やす前に標準機能で済むか考える
- Android はライブラリを増やさない（OkHttp だけ追加する）
- 1 ステップずつ動く状態を保つ。大きな変更の前に、どこまで動いているか確認する
- Android のビルドと実機での確認はユーザーが行う。**何をビルドして、実機で何を確認すればよいか**を毎回はっきり伝える
- 30 分以上かかりそうなときは、着手前に「簡易版でいくか」を提案する
- Origin チェックや CSRF 対策は無効にしない（API は `ActionController::API` + トークン認証で分ける）
- `docs/kaigi-on-rails-2026/raw/` は元資料なので編集・削除しない
- コミットはユーザーに頼まれたときだけ行う

## レビューの手順
- ユーザーに選択肢を提示する前、フェーズの完了を報告する前、コミットする前に、
  必ず reviewer サブエージェントに計画・差分・テスト結果を渡して判定をもらう。
- ユーザーへの報告には、reviewer の「判定」「修正・追加の条件」「人間が確認すべきこと」をそのまま含める。
- reviewer の指摘に反対する場合は、その理由も併記する（黙って無視しない）。
- reviewer に渡すのは、自分の説明ではなく証拠（git diff、テスト結果、ログ）を中心にする。
