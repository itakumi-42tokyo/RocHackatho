class Device < ApplicationRecord
  has_secure_token
  has_many :device_events, dependent: :destroy
  has_many :break_requests, dependent: :destroy

  LOCK_MODES = %w[overlay pinning full].freeze
  STATUSES = %w[online inactive offline].freeze
  BUTTON_KINDS = %w[break toilet help custom].freeze
  MAX_BUTTONS = 2

  # 死活判定のしきい値（秒）
  INACTIVE_AFTER = 15
  OFFLINE_AFTER = 60

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
  scope :jailbreakers, -> { where("escape_count > 0").order(escape_count: :desc) }
  scope :fastest_escapes, -> { where.not(best_escape_seconds: nil).order(best_escape_seconds: :asc) }

  after_create_commit  { refresh_admin }
  after_update_commit  :push_state_to_device, if: :device_facing_change?
  after_update_commit  { refresh_admin }

  # Android に送る現在の状態。命令ではなく「今の状態」をまるごと送る
  def state_payload
    {
      type: "state",
      locked: locked,
      mode: lock_mode,
      opacity: opacity,
      message: lock_message.to_s,
      lock_path: "/lock?token=#{token}"
    }
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
    attrs = { locked: true, locked_at: Time.current }
    attrs[:lock_mode] = mode if mode.present?
    attrs[:opacity] = opacity if opacity
    attrs[:lock_message] = message if message
    update!(attrs)
    log_event("lock", mode: lock_mode)
  end

  def unlock!
    update!(locked: false, locked_at: nil)
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

  # ロック中に接続が途絶えた／覆いが外れた = 脱獄
  def mark_escaped!
    return unless locked?

    seconds = locked_at ? (Time.current - locked_at).to_i : nil
    self.escape_count += 1
    self.best_escape_seconds = seconds if seconds && (best_escape_seconds.nil? || seconds < best_escape_seconds)
    save!
    log_event("escaped", seconds: seconds)
  end

  private

  # Android の画面に関わる変更があったか
  def device_facing_change?
    (saved_changes.keys & %w[locked lock_mode opacity lock_message]).any?
  end

  # 現在の状態を端末（Android）に送る
  def push_state_to_device
    DeviceChannel.broadcast_to(self, state_payload)
  end

  # 管理画面のカードとランキングを更新する（Turbo Streams）
  def refresh_admin
    broadcast_replace_to "admin", target: ActionView::RecordIdentifier.dom_id(self),
                                  partial: "admin/device", locals: { device: self }
    broadcast_replace_to "admin", target: "ranking", partial: "admin/ranking"
  end
end
