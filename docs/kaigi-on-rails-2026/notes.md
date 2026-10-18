# Kaigi on Rails 2026 まとめ（ハッカソン用）

- 開催: 2026-10-16（金）〜 10-17（土）
- 会場トラック: Magenta Hall / Lime Hall
- 公式スケジュール: https://kaigionrails.org/2026/schedule/
- 元資料: `raw/1day.txt`, `raw/Day2.txt`（聴講メモ）、`raw/photos/20261017_*.jpg`（Day2 のスライド写真 4 枚）

> 凡例: **[メモ]** = 手元のメモを整理したもの / **[写真]** = 写真から書き起こしたもの / *(推定)* = メモとスケジュールを照らし合わせて推測した対応関係

---

## 1. 公式スケジュール

### Day 1 — 10/16（金）

| 時間 | Magenta Hall | Lime Hall |
|---|---|---|
| 10:00–11:00 | 開場・受付 | |
| 11:00–11:05 | Opening | |
| 11:05–11:20 | Sponsor LT 1〜3 | |
| 11:20–12:00 | **Keynote: "Where the tracks go next"** — dhh (EN) | |
| 12:00–13:30 | Lunch | |
| 13:30–14:00 | Active Record Connection Adaptersにおける長年の課題に再び取り組む — yahonda | FactoryBotをやめればRSpecは速くなるのか？ — nissyi-gh |
| 14:10–14:25 | AIエージェントのデバッグ能力を向上させよう — AI時代にRailsが輝く理由 — rira100000000 | Local CI × GitHub Actions ― 長所を活かすハイブリッドCIの実践 — gogutan |
| 14:35–15:05 | Inertia Rails: The One-Person Framework with React & Friends — skryukov (EN) | Domain Modeling with Vanilla Rails: 「操作」から再考するRailsの設計論 — yasaichi |
| 15:05–15:50 | Coffee Break | |
| 15:50–16:05 | PumaからFalconに移行したRailsアプリケーションでの実践 — falcon8823 | 現場と育てるRailsモデリング 〜Spreadsheetから始めたモデル設計〜 — siroemk |
| 16:15–16:45 | Herb in Rails 8.2: Your ERB views, now HTML-aware — marcoroth (EN) | ActionController meets Protocol Buffers… たのしい API スキーマ定義! — sorah |
| 16:55–17:10 | 小さく作ってわかるRailsの仕組み 〜mini-rails〜 — Hitoshi-Noborikawa | Railsバージョンを4倍にした話 〜Rails 2系から8系へ〜 — skytomo221 |
| 17:20–17:50 | Event is what happens — moro | Railsのためのパスキー実践入門 〜マルチテナントSaaSでの意思決定〜 — utakaha |
| 18:00–18:30 | 真のREST 2026 — tkawa | 全ての永続トークンを、生まれる前に消し去りたい！ — sylph01 |

### Day 2 — 10/17（土）

| 時間 | Magenta Hall | Lime Hall |
|---|---|---|
| 9:30–10:00 | 開場・受付 | |
| 10:00–10:15 | Sponsor LT 4〜6 | |
| 10:15–10:55 | **Keynote** — matz (JA) | |
| 11:05–11:20 | 作れる、でも消せるか？──安全に「枯らして消す」機能削除術 — ksbmyk | デプロイの先まで全部面倒を見る ― Kamal を社内 PaaS に育てた話 — dkan75 |
| 11:30–12:00 | The Revenge of the Cucumber: Safety Nets for AI Code — Gawyn (EN) | Zen and the Art of File Upload Maintenance — udzura |
| 12:00–13:30 | Lunch | |
| 13:30–13:45 | RailsはAIという責務をどう受け入れるのか — aoki-ryusei | Hypertext on Rails — HATEOAS が示す Rails の正しさ — taiju |
| 13:55–14:25 | ActionCableの相手はブラウザだけじゃない — Railsでデバイス群をリアルタイム管制する — yujiteshima | Railsで挑む大量データ永続化 〜600億件を永続化するための設計とボトルネックとの戦い〜 — sho-work |
| 14:35–15:05 | ~~How Reasonable Decisions Created a Security Incident — pwim~~ **（中止）** | Browser Spec: HotwireをRubyでテストする — takahashim |
| 15:05–15:50 | Coffee Break | |
| 15:50–16:05 | Refining Active Record — shugo | その Valkey 使いこなしていますか？ — onk |
| 16:15–16:45 | How to Design Configuration for Rails Applications — willnet | 3回つくってわかった、定期実行ジョブ基盤の本質情報 — takai |
| 16:55–17:25 | Web Framework Benchmark Battle 2026, Any% — amatsuda | |
| 17:35–18:05 | Solid Queue: two years on Rails — rosa (EN) | |
| 18:05–18:15 | Closing | |
| 18:30–20:30 | After Party | |

---

## 2. Day 1 聴講メモ（`raw/1day.txt` を整理）

### スポンサー LT
| LT | 会社 | キーワード |
|---|---|---|
| LT1 | Mov株式会社 | DuckDB（ブースにも行く予定） |
| LT2 | with株式会社 | Rails モノリス |
| LT3 | Timee株式会社 | モジュラーモノリス |

### Keynote: "Where the tracks go next" — DHH
- 話題に出たもの: **Omarchy**、**Spinel**、**Lightroom**、Fuji Speedway のレース、絵文字 3 つ
- 印象に残ったフレーズ
  - "The best part of Japan is Japanese."
  - "If you teleported the Japanese to another country, that country would be Japan."
  - "You are not alone."
  - 学習は投資である。
  - "There are decades where nothing happens, and there are weeks where decades happen."
  - "Look at all the things I'm not doing."
  - "People have their heads exploded."
  - 以前は、AI にゼロから作らせるのは優秀ではなかった。
  - "Tired: writing. Wired: reading."（コードを書くより読む時代へ）
  - "Share libraries, not abstractions." *(メモでは "Share Liraries. ot Astruct." — 推定)*
  - "In the beginner's mind there are many possibilities, but in the expert's there are few."

### （発表名不明）インフラ構成メモ
- S3 / ElastiCache / OpenSearch / Rails モノリス
- *(13:30 枠のメモと思われるが、どの発表か特定できず)*

### AIエージェントのデバッグ能力を向上させよう — AI時代にRailsが輝く理由（rira100000000）
- debug 用 MCP、APM を活用
- 「仮説」を「断定」にする — ソースコード上だけでなく、**実行環境で証拠を出す**
- Rails が有利な理由: ① Reflection ② モノリス ③ Notifications（ActiveSupport::Notifications）
- テスト実行の瞬間のプロセスに入れる。例外ブレークポイントを立てれば、その瞬間を再現できる
- 不可逆な操作か／実行してよい環境かの判断は人間が行う

### PumaからFalconに移行したRailsアプリケーションでの実践（falcon8823）
- Unicorn → Puma → Falcon
- Falcon は API 待ち（I/O 待ち）の時間を有効活用する
- Fiber 対応していないと速くならない
- I/O が発生しない処理（例: 検索 API）では CPU 効率の改善は見られなかった
- Ruby master、PumaPy *(表記はメモのまま)*

### ActionController meets Protocol Buffers… たのしい API スキーマ定義!（sorah）
- シリアライズ
- 「JSON に型がなくて困ったことはないですか？」
- API スキーマとは何か

### 小さく作ってわかるRailsの仕組み 〜mini-rails〜（Hitoshi-Noborikawa）
- request → Rack → Router → Controller → …
- MiniRecord（ActiveRecord のミニ実装）

### Railsのためのパスキー実践入門 〜マルチテナントSaaSでの意思決定〜（utakaha）
- Conditional UI か、パスキー専用ボタンか
- FIDO Alliance
- ページを開いた際に自動入力させるのは是か非か
- パスキーと 2 要素認証の関係
- UV フラグ（User Verification）
- パスキーの識別方法: AAGUID（128bit）
- WebAuthn により、1 ユーザーに複数パスキーを登録可能にする

### 真のREST 2026（tkawa）
- REST の提唱者: Roy T. Fielding
- サーバーとクライアントは「表現（representation）」を送り合っている
- メッセージは自己完結的（self-descriptive）
- REST API はハイパーテキストでなければならない → **JSON API は RESTful ではない**
- Web の成功要因: 新しいものが来たときに（クライアント側の）更新が不要
- MPA と SPA

---

## 3. Day 2 聴講メモ（`raw/Day2.txt` を整理）

### スポンサー LT
| LT | 会社 | キーワード |
|---|---|---|
| LT1 | Leaner *(推定: 株式会社Leaner Technologies)* | — |
| LT2 | Wantedly | PostgreSQL → BigQuery、mendy *(表記はメモのまま)* |
| LT3 | Studyplus | miko *(表記はメモのまま)* |

### ビット演算メモ（XOR / XNOR）
```
  101
  111
  --- XOR
  010

  010 → 111 と XNOR すると 101 に戻る（XNOR だけで変換する）
```
*(どのセッションのメモかは不明。LT またはキーノートの例題と推定)*

### Keynote — Matz
- 12 言語 × 20 run × 2 set で AI に開発させて比較
  - トークン消費量を計測 → **Ruby は消費量が少なく、開発時間も短い**
  - ただし最新モデルでは言語間の差は小さい
  - Ruby は実行コストが高い
- 「AI gate」とは / 「ship する」とは
- Ruby で開発して **Spinel でデプロイ**（AOT コンパイル）
- Roundhouse コンパイルと Spinel *(表記は推定)*
- without metaprogramming at runtime（実行時メタプログラミングなし）
- Compile when shipped

### The Revenge of the Cucumber: Safety Nets for AI Code（Gawyn）
- SciFi / BCN（バルセロナ）*(メモ "SCI FI bcn")*
- Sparkle 介護システム
- 参考: https://note.shiftinc.jp/n/n1fa2e3780f73
- **デプロイとリリースを切り分ける**

### RailsはAIという責務をどう受け入れるのか（aoki-ryusei）*(推定)*
- Active Agent（メモには見出しのみ）

### ActionCableの相手はブラウザだけじゃない — Railsでデバイス群をリアルタイム管制する（yujiteshima）
**[メモ]**
- クライアントが人間（ブラウザ）ではなく Raspberry Pi だったら？
- Raspberry Pi の出荷の約 7 割は産業用途
- エッジゲートウェイを作ってみたという話
- リアルタイム更新で ActionCable と Turbo をどう使い分けるか
- Rails の相手はブラウザだけではない。ActiveJob も活用
- 構成: 制御プレーン ／ Raspberry Pi → Rails → Web
- デバイステーブルは 5 カラム
- Turbo Streams（Hotwire）
- 3 秒に 1 回ハートビート。**15 秒で deactivate、60 秒で offline**
- WebSocket + ActiveJob。受け口はコネクション
- Job にユニーク ID を付けて重複を排除
- タスクを渡すと画面のバッジが青く光る。BG ではなく Job を渡す
- 4 デバイス × 15fps なら Turbo でもいける
- **"Never let Turbo replace the canvas."**
- Raspberry Pi は RTC がなく、電源断後は最後に電源を入れた時刻から再開 → NTP が必要
- Rails 8.0 から Solid Cable
- "the next fleet of orchestrate"

**[写真] スライド 19 `raw/photos/20261017_140600.jpg` — 04 · Turbo Streams or raw ActionCable / "Same frame, measured two ways"**

| per frame (256 bins) | Turbo Streams · HTML | raw ActionCable · compact | HTML is |
|---|---|---|---|
| Payload on the wire | 10.96 KB | 0.42 KB | 26× heavier |
| Server work | 0.09 ms (render) | ≈ 0 ms (base64) | 31× |
| Client paint | 0.236 ms (rebuild + reflow) | 0.032 ms (one canvas column) | 7.4× |
| DOM nodes created | 257 | 0 | ∞ |

計測環境: ruby 3.4 · Rails 8.1 · headless Chrome · 5,000 / 3,000 iterations. Full data in bench/results.md.

字幕: 「256 本のバーを毎回作り、並べ直すと 1 列。1 本書き足すと 3 になる。…毎フレーム DOM ノードを作っている」

**[写真] スライド 22 `raw/photos/20261017_140744.jpg` — 04 · Turbo Streams or raw ActionCable / "The rule"**

| 用途 | 例 | 選択 | 理由 |
|---|---|---|---|
| Low-frequency state changes | a device went offline · a notification · a badge | **→ Turbo Streams** | Server-rendered HTML, zero client code. The swap cost is negligible at this rate. |
| High-frequency numeric streams | waveforms · sensor values · tens of Hz | **→ raw ActionCable + canvas** | Send compact numbers, paint on the client, throttle on the server. |

- **Switching point:** a few hundred messages per second, or tens of thousands of DOM nodes per second.
- **Outside IoT, the same line:** new notifications and comments → Turbo Streams. An order book, a live traffic graph, dozens of progress bars moving at once → numbers on the wire, painting on the client.
- 字幕: 「IoT の話に聞こえるが、普通の Web アプリにも当てはまる」

**[写真] スライド 26 `raw/photos/20261017_141309.jpg` — 05 · Lessons / "Three things that broke because the client wasn't a browser"**

1. **Origin** — Browsers send an Origin, devices don't, so Action Cable turns the Pi away. Action Controller lets the same request in — "We accept blank origin headers because some user agents don't send it." RFC 6455 only requires a browser to send one. The shortcut is to switch the protection off; ours stayed off for three months.
2. **Half-open** — Pull the cable and nobody says goodbye. The server keeps the dead connection, and the dead connection can take a returned device down with it.
3. **Clocks** — The protocol carries timestamps. None of them decides anything. On purpose.

字幕: 「検査そのものを無効にする設定で Raspberry Pi が繋がるようにし、7 月から 3 か月そのまま動かしていた。でも確認が防ぐのは、よそのサイトが人のブラウザに勝手にうちのサーバーへ接続させるような攻撃（CSWSH）。なので検証は必要だった」

**[写真] スライド 27 `raw/photos/20261017_141527.jpg` — 05 · Lessons / "How long until the server notices?"**

| what happened to the device | the server notices after |
|---|---|
| cable pulled — server on macOS | 20–40 s |
| cable pulled — server on Linux, defaults | about 16 min |
| its process froze | never |
| any of the above, with pongs (rails/rails #58798) | 4–8 s |

- On a Mac the dead connection cleans itself up in seconds, so you never see the problem. Production runs on Linux.
- Found on the real Pi: it reconnected — and ten seconds later the old connection finally closed and marked it offline. **Only a device's current connection may take it offline.**
- 字幕: 「プログラムが固まっても TCP から見ると接続は正常なので、相手の OS は生きていて返事をする。固まっているのはプログラムなので、OS には分かりようがない」

### その Valkey 使いこなしていますか？（onk）
- Sorted Set が爆速
- `ZINCRBY` でアクセスランキング
- `ZUNIONSTORE ... WEIGHTS` で重み付き集計
- Valkey Search: セマンティックサーチ、RAG、レコメンド

### その他
- 「pines」— メモのみ。詳細不明

---

## 4. ハッカソンで使えそうなポイント

| テーマ | 使えるネタ | 出典 |
|---|---|---|
| リアルタイム UI | 低頻度の状態変化は Turbo Streams、高頻度の数値は raw ActionCable + canvas。切り替え目安は数百 msg/s | yujiteshima |
| デバイス連携 | ハートビート 3s / deactivate 15s / offline 60s、Job のユニーク ID で重複排除、ping/pong で死活監視、「現在の接続だけが offline にできる」 | yujiteshima |
| セキュリティ | ActionCable の Origin チェックは安易に切らない（CSWSH 対策） | yujiteshima |
| ランキング・検索 | Valkey の Sorted Set（`ZINCRBY` / `ZUNIONSTORE`）、Valkey Search で RAG・レコメンド | onk |
| AI 開発 | debug MCP + 実行環境で証拠を取る。Ruby はトークン消費が少ない | rira100000000 / matz |
| 認証 | パスキー（WebAuthn、Conditional UI、AAGUID） | utakaha |
| API 設計 | Protocol Buffers で型付き API スキーマ、ハイパーテキストとしての REST | sorah / tkawa |
| リリース戦略 | デプロイとリリースを分ける（フィーチャーフラグ等） | Gawyn |
| Rails 8 系 | Solid Cable / Solid Queue（DB ベースで Redis 不要） | yujiteshima / rosa |
