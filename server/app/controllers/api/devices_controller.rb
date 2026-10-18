class Api::DevicesController < Api::BaseController
  # 端末登録。名前を受け取り、token を返す。以後 Android はこの token で接続する
  def create
    device = Device.create!(name: params[:name].presence || "名無し端末")
    render json: { id: device.id, token: device.token, name: device.name }, status: :created
  end
end
