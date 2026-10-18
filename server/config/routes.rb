Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get "lock_preview" => "lock_previews#show", as: :lock_preview

  root "pages#home"
end
