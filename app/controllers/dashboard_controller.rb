class DashboardController < ApplicationController
  def show
    @accounts = Account.order(current: :desc, label: :asc).includes(:sync_runs)
    @spend_by_account = PsnTransaction.purchases.group(:account_id, :currency).sum(:amount_minor)
    @refunds_by_account = PsnTransaction.refunds.group(:account_id, :currency).sum(:amount_minor)
  end
end
