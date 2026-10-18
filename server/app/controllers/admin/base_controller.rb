class Admin::BaseController < ApplicationController
  http_basic_authenticate_with(
    name: ENV.fetch("ADMIN_USER", "admin"),
    password: ENV.fetch("ADMIN_PASSWORD", "admin")
  )
  layout "admin"
end
