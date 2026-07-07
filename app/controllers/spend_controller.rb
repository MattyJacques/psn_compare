class SpendController < ApplicationController
  FILTERS = %w[games twice refunds].freeze

  def index
    @filter = params[:filter].presence_in(FILTERS)
    @second_copy_ids = SecondCopies.transaction_ids
    @lifetime = net_by_currency(PsnTransaction.all)
    @by_account = Account.order(current: :desc, label: :asc)
                         .map { |a| [ a, net_by_currency(a.psn_transactions) ] }
    @transactions = filtered.order(occurred_at: :desc).includes(:account).limit(200)
  end

  private

  def net_by_currency(scope)
    spend = scope.spend_kinds.group(:currency).sum(:amount_minor)
    refunds = scope.refunds.group(:currency).sum(:amount_minor)
    spend.merge(refunds.transform_values(&:-@)) { |_, s, r| s + r }.except(nil)
  end

  def filtered
    case @filter
    when "games" then PsnTransaction.purchases
    when "twice" then PsnTransaction.where(id: @second_copy_ids.to_a)
    when "refunds" then PsnTransaction.refunds
    else PsnTransaction.all
    end
  end
end
