# 利用者がロック画面から送る「休憩したい」などのリクエスト。
# 管理者が承認／却下する（承認・解除の処理はフェーズ3・4）。
class BreakRequest < ApplicationRecord
  belongs_to :device

  KINDS = %w[break toilet help custom].freeze
  STATUSES = %w[pending approved denied expired cancelled].freeze

  PENDING_TTL = 10.minutes # 承認待ちのまま放置されたら期限切れにする
  BODY_MAX = 100           # 自由入力の文字数上限

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :body, length: { maximum: BODY_MAX }
  validates :body, presence: true, if: -> { kind == "custom" }
  validate :only_one_open_per_device, on: :create

  before_validation :set_defaults, on: :create

  after_create_commit :refresh_lock_screen
  after_update_commit :refresh_lock_screen

  # 「まだ処理待ち」= pending かつ期限内。端末が同時に持てるのは 1 件だけ
  scope :open, -> { where(status: "pending").where("expires_at > ?", Time.current) }
  scope :recent, -> { order(created_at: :desc) }

  def open?
    status == "pending" && expires_at.present? && expires_at.future?
  end

  # 利用者が自分で取り消す
  def cancel!
    return false unless open?
    update!(status: "cancelled", responded_at: Time.current)
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

  # ロック画面の該当端末だけに、今の状態を Turbo Streams で送る（再読み込みしない）
  def refresh_lock_screen
    broadcast_replace_to [device, :lock],
                         target: "lock_request_zone",
                         partial: "lock/request_zone",
                         locals: { device: device }
  end
end
