Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # 管理者
  namespace :admin do
    root "devices#index"
    resources :devices, only: [:update] do
      member do
        patch :extend_unlock # 一時解除を延長する
        patch :relock        # 今すぐ再ロックする
      end
      collection do
        post :lock_all
        post :unlock_all
        post :update_lock_screen # 全員の lock_title / lock_buttons を一括設定
      end
    end
    # 休憩リクエストの承認・却下
    resources :break_requests, only: [] do
      member do
        patch :approve
        patch :deny
      end
    end
  end

  # Android アプリ向け API
  namespace :api do
    resources :devices, only: [:create]
  end

  # Android の WebView が表示するロック画面（初回のみトークン、以降は Cookie で端末を特定）
  get "lock" => "lock#show", as: :lock

  # ロック画面からの休憩リクエスト（Cookie 認証 + CSRF）
  resources :break_requests, only: [:create] do
    patch :cancel, on: :member
  end

  # 開発用: ロック画面の見た目の確認
  get "lock_preview" => "lock_previews#show", as: :lock_preview

  root "pages#home"
end
