# ロック画面の見た目をブラウザで確認するためのページ（開発用）
class LockPreviewsController < ApplicationController
  THEMES = %w[jail kaigi].freeze

  layout "lock"

  def show
    @theme = THEMES.include?(params[:theme]) ? params[:theme] : THEMES.first
  end
end
