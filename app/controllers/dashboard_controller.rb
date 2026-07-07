class DashboardController < ApplicationController
  def show
    redirect_to new_account_path and return if Account.none?

    @main = Account.current
    @accounts = Account.order(current: :desc, label: :asc)
    @stats = DashboardStats.call(@main) if @main
  end
end
