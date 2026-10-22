class Api::DevicesController < Api::BaseController
  # 端末登録。client_id（ANDROID_ID）と名前を受け取り、token を返す。
  # 同じ client_id は同じ端末として扱い、token を作り直す（再インストールで別端末にならない）。
  def create
    device = Device.register!(client_id: params[:client_id], name: params[:name])
    render json: { id: device.id, token: device.token, name: device.name }, status: :created
  end
end
