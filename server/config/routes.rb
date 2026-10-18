Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # 管理者
  namespace :admin do
    root "devices#index"
    resources :devices, only: [:update] do
      collection do
        post :lock_all
        post :unlock_all
      end
    end
  end

  # Android アプリ向け API
  namespace :api do
    resources :devices, only: [:create]
  end

  # Android の WebView が表示するロック画面（トークンで端末を特定）
  get "lock" => "lock#show", as: :lock

  # 開発用: ロック画面の見た目の確認
  get "lock_preview" => "lock_previews#show", as: :lock_preview

  root "pages#home"
end
