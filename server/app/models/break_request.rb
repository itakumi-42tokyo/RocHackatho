# 利用者がロック画面から送る「休憩したい」などのリクエスト。
# 管理者が承認／却下する（承認・解除の処理はフェーズ3・4）。
class BreakRequest < ApplicationRecord
  belongs_to :device

  KINDS = %w[break toilet help custom].freeze
  STATUSES = %w[pending approved denied expired cancelled].freeze

  PENDING_TTL = 10.minutes # 承認待ちのまま放置されたら期限切れにする
  BODY_MAX = 100           # 自由入力の文字数上限

  PRESET_MINUTES = [5, 10, 15, 30].freeze           # 承認時に選べる解除分数
  DEFAULT_MINUTES = { "toilet" => 5, "break" => 10, "help" => 10, "custom" => 10 }.freeze

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :body, length: { maximum: BODY_MAX }
  validates :body, presence: true, if: -> { kind == "custom" }
  validate :only_one_open_per_device, on: :create

  before_validation :set_defaults, on: :create

  after_create_commit :refresh_screens
  after_update_commit :refresh_screens

  # 「まだ処理待ち」= pending かつ期限内。端末が同時に持てるのは 1 件だけ
  scope :open, -> { where(status: "pending").where("expires_at > ?", Time.current) }
  scope :pending_due, -> { where(status: "pending").where(expires_at: ..Time.current) }
  scope :recent, -> { order(created_at: :desc) }

  # 期限切れの pending をまとめて expired にする。
  # 作成前に呼んで、部分ユニークインデックス（pending は端末ごと 1 件）と整合させる。
  def self.expire_due_for(device)
    device.break_requests.pending_due.update_all(status: "expired", responded_at: Time.current)
  end

  def open?
    status == "pending" && expires_at.present? && expires_at.future?
  end

  # 利用者が自分で取り消す
  def cancel!
    return false unless open?
    update!(status: "cancelled", responded_at: Time.current)
  end

  # 管理者が承認する。locked は変えず、端末に一時解除（unlock_until）を与え、
  # その時刻に状態を送り直す再ロックジョブを予約する（フェーズ4の核だけ前倒し）。
  def approve!(minutes:, reply: nil)
    return false unless status == "pending"

    minutes = minutes.to_i
    minutes = default_minutes unless PRESET_MINUTES.include?(minutes)
    transaction do
      update!(status: "approved", unlock_minutes: minutes, reply: reply.presence, responded_at: Time.current)
      device.grant_break!(minutes)
    end
    RelockDeviceJob.set(wait_until: device.unlock_until).perform_later(device.id)
    true
  end

  # 管理者が却下する（返信つき）
  def deny!(reply: nil)
    return false unless status == "pending"
    update!(status: "denied", reply: reply.presence, responded_at: Time.current)
  end

  # kind ごとの既定解除分数（画面の初期選択に使う）
  def default_minutes
    DEFAULT_MINUTES.fetch(kind, 10)
  end

  # 期限が来た pending を期限切れにする（ExpireBreakRequestJob から呼ぶ）
  def expire_if_due!
    return false unless status == "pending" && expires_at.present? && expires_at.past?
    update!(status: "expired", responded_at: Time.current)
  end

  # ロック画面・管理画面に出す見出し
  def label
    base = { "break" => "休憩", "toilet" => "トイレ", "help" => "ヘルプ", "custom" => "リクエスト" }[kind] || kind
    body.present? ? "#{base}: #{body}" : base
  end

  private

  def set_defaults
    self.status = "pending" if status.blank?
    self.expires_at ||= Time.current + PENDING_TTL
  end

  # 同じ端末で未処理（open）のリクエストが二重にならないようにする
  def only_one_open_per_device
    return unless device

    if device.break_requests.open.where.not(id: id).exists?
      errors.add(:base, "すでに承認待ちのリクエストがあります")
    end
  end

  # ロック画面（端末）と管理画面の両方を Turbo Streams で更新する（再読み込みしない）
  def refresh_screens
    # 端末のロック画面：リクエスト欄だけ差し替え
    broadcast_replace_to [device, :lock],
                         target: "lock_request_zone",
                         partial: "lock/request_zone",
                         locals: { device: device }
    # 管理画面：この端末のカードを差し替え（承認待ちの表示が出る）
    broadcast_replace_to "admin",
                         target: ActionView::RecordIdentifier.dom_id(device),
                         partial: "admin/device",
                         locals: { device: device }
    # 管理画面：承認待ち件数バナーを更新（タブのタイトル・新着音もこれで動く）
    broadcast_replace_to "admin", target: "pending_banner", partial: "admin/pending_banner"
  end
end
