class Device < ApplicationRecord
  has_secure_token
  has_many :device_events, dependent: :destroy
  has_many :break_requests, dependent: :destroy

  LOCK_MODES = %w[overlay pinning full].freeze
  STATUSES = %w[online inactive offline].freeze
  BUTTON_KINDS = %w[break toilet help custom].freeze
  MAX_BUTTONS = 2

  # 死活判定のしきい値（秒）。ハートビートは 30 秒間隔なので、取りこぼし 1〜3 回を見込んで余裕を持たせる
  INACTIVE_AFTER = 45
  OFFLINE_AFTER = 90

  validates :name, presence: true
  validates :lock_mode, inclusion: { in: LOCK_MODES }
  validates :opacity, inclusion: { in: 0..100 }

  scope :recent, -> { order(created_at: :desc) }

  # 署名付き Cookie（{ "id" =>, "gen" => }）から端末を取り出す。
  # token の世代が一致しないときは無効（token 回転で古い Cookie を弾く）。
  def self.from_lock_cookie(data)
    return nil unless data.is_a?(Hash)

    data = data.symbolize_keys
    device = find_by(id: data[:id])
    device if device && device.token_generation == data[:gen]
  end

  # 端末登録。client_id（ANDROID_ID）があれば同じ端末として扱い、token を作り直す
  # （再インストールでも別端末にならない。古い token は無効になる＝なりすまし対策）。
  def self.register!(client_id:, name:)
    name = name.presence || "名無し端末"
    if client_id.present? && (device = find_by(client_id: client_id))
      device.rotate_token!
      device.update!(name: name)
      device
    else
      create!(client_id: client_id.presence, name: name)
    end
  end
  scope :jailbreakers, -> { where("escape_count > 0").order(escape_count: :desc) }
  scope :fastest_escapes, -> { where.not(best_escape_seconds: nil).order(best_escape_seconds: :asc) }

  # 管理画面の見た目に関わる列。これが変わったときだけリフレッシュを配信する
  # （last_seen_at・connection_id のような見た目に出ない更新では配信しない）
  ADMIN_VISIBLE_COLUMNS = %w[
    name status locked lock_mode opacity lock_message lock_title lock_buttons
    unlock_until escaped escape_count best_escape_seconds client_id
  ].freeze

  # 管理画面は Turbo 8 のページリフレッシュ（morph）で更新する（個別の replace/append はしない）。
  # 見た目が変わるときだけ配信する（ハートビートのたびに全体を取り直さない）
  after_commit         -> { broadcast_refresh_to "admin" }, if: :admin_visible_change?
  # 端末（Android）へは従来どおり個別に状態を送る（ちらつきを避ける）
  after_update_commit  :push_state_to_device, if: :device_facing_change?

  # Android に送る現在の状態。命令ではなく「今の状態」をまるごと送る。
  # locked は「実効ロック」= ロック中かつ一時解除の期限が切れている、で計算する。
  def state_payload
    {
      type: "state",
      locked: effective_locked?,
      mode: lock_mode,
      opacity: opacity,
      message: lock_message.to_s,
      lock_path: "/lock?token=#{token}"
    }
  end

  # 実効ロック。unlock_until が未来のあいだは一時的に解除扱い
  def effective_locked?
    locked? && (unlock_until.nil? || unlock_until.past?)
  end

  # 一時解除の残り秒（管理画面の表示用）。解除していなければ 0
  def unlock_remaining_seconds
    return 0 unless unlock_until && unlock_until.future?
    (unlock_until - Time.current).ceil
  end

  # 承認時に呼ぶ。locked はそのままに、一時解除の期限だけを入れる。
  # 承認は脱獄状態も解消する（escaped をクリア）＝「一時解除中」と「🚨脱獄中」が同時に出ない。
  # unlock_until が変わると device_facing_change? が効いて端末へ状態が送られる（＝解除が届く）。
  def grant_break!(minutes)
    update!(unlock_until: Time.current + minutes.to_i.minutes, escaped: false)
  end

  # 一時解除を延長する。今の残り時間（未来なら）に足す。足した後の時刻を返す
  def extend_unlock!(minutes)
    base = unlock_until&.future? ? unlock_until : Time.current
    update!(unlock_until: base + minutes.to_i.minutes)
    unlock_until
  end

  # 今すぐ再ロックする（一時解除を打ち切る）。locked はそのまま、期限だけ消す
  def relock_now!
    update!(unlock_until: nil)
  end

  # 今の状態を端末へ送り直す（再ロックの予約ジョブから呼ぶ。列の変更が無くても送る）
  def broadcast_state!
    DeviceChannel.broadcast_to(self, state_payload)
  end

  # ロック画面の内容をデータで定義する（HTML 描画と JSON API で共通に使う。将来の iOS ネイティブ描画用）
  def lock_screen_data
    {
      title: lock_title.presence || "LOCKED",
      message: lock_message.to_s,
      buttons: normalized_buttons
    }
  end

  # 最大 MAX_BUTTONS 件、既知の kind だけに整える
  def normalized_buttons
    Array(lock_buttons).first(MAX_BUTTONS).filter_map do |b|
      label = b["label"].to_s
      kind = b["kind"].to_s
      next if label.blank? || BUTTON_KINDS.exclude?(kind)
      { "label" => label, "kind" => kind }
    end
  end

  def lock!(mode: nil, opacity: nil, message: nil)
    # 手動ロックは一時解除より優先する（残っている unlock_until は消す）。新しいロックなので escaped もリセット
    attrs = { locked: true, locked_at: Time.current, unlock_until: nil, escaped: false }
    attrs[:lock_mode] = mode if mode.present?
    attrs[:opacity] = opacity if opacity
    attrs[:lock_message] = message if message
    update!(attrs)
    log_event("lock", mode: lock_mode)
  end

  def unlock!
    update!(locked: false, locked_at: nil, unlock_until: nil, escaped: false)
    log_event("unlock")
  end

  # 今この端末が持っている未処理（承認待ち）のリクエスト
  def open_break_request
    break_requests.open.order(created_at: :desc).first
  end

  def online?  = status == "online"
  def offline? = status == "offline"

  def log_event(kind, extra = {})
    device_events.create!(kind: kind, payload: extra)
  end

  # token を回転させ世代を上げる（ANDROID_ID 再登録などで古い token・Cookie を無効にする）
  def rotate_token!
    regenerate_token
    increment!(:token_generation)
  end

  # ロック中に接続が途絶えた／覆いが外れた = 脱獄。
  # ・一時解除中（unlock_until が未来）は正当に使えるので数えない（実効ロックで判定）
  # ・「ロック中 → 逃げた」の状態変化 1 回につき 1 回だけ数える（escaped フラグ）。
  #   ハートビート（数秒おき）で何度 report が来ても二重に数えない
  def mark_escaped!
    return unless effective_locked?
    return if escaped?

    seconds = locked_at ? (Time.current - locked_at).to_i : nil
    self.escaped = true
    self.escape_count += 1
    self.best_escape_seconds = seconds if seconds && (best_escape_seconds.nil? || seconds < best_escape_seconds)
    save!
    log_event("escaped", seconds: seconds)
    Rails.logger.info("[jail] device=#{id} escaped! count=#{escape_count}")
  end

  # 覆いが戻った／連れ戻された。次に逃げたらまた 1 回数えられるようにする
  def mark_recaptured!
    return unless escaped?

    update!(escaped: false)
    log_event("recaptured")
    Rails.logger.info("[jail] device=#{id} recaptured")
  end

  private

  # 管理画面の見た目に関わる変更があったか（削除も含む）
  def admin_visible_change?
    destroyed? || (saved_changes.keys & ADMIN_VISIBLE_COLUMNS).any?
  end

  # Android の画面に関わる変更があったか（文言・ボタンの一括変更や一時解除も含む）
  def device_facing_change?
    (saved_changes.keys & %w[locked lock_mode opacity lock_message lock_title lock_buttons unlock_until]).any?
  end

  # 現在の状態を端末（Android）に送る
  def push_state_to_device
    broadcast_state!
  end
end
