# Per-account, per-currency money math from synced transactions. No currency
# conversion: mixed currencies are reported side by side.
class SpendSummary
  CurrencyTotals = Data.define(:currency, :purchases, :refunds, :wallet, :net, :by_year)

  def self.call
    Account.order(:label).index_with { |account| new(account).totals }
             .reject { |_, totals| totals.empty? }
  end

  def self.biggest_purchases(limit: 10)
    PsnTransaction.purchases.order(amount_minor: :desc).limit(limit).includes(:account)
  end

  def initialize(account)
    @account = account
  end

  def totals
    currencies.map do |currency|
      scope = @account.psn_transactions.where(currency:)
      purchases = scope.purchases.sum(:amount_minor)
      refunds = scope.refunds.sum(:amount_minor)
      CurrencyTotals.new(currency:, purchases:, refunds:,
                         wallet: scope.wallet_funding.sum(:amount_minor),
                         net: purchases - refunds, by_year: by_year(scope))
    end
  end

  private

  def currencies
    @account.psn_transactions.where.not(currency: nil).distinct.pluck(:currency).sort
  end

  def by_year(scope)
    purchases = scope.purchases.group("CAST(strftime('%Y', occurred_at) AS INTEGER)").sum(:amount_minor)
    refunds = scope.refunds.group("CAST(strftime('%Y', occurred_at) AS INTEGER)").sum(:amount_minor)
    purchases.merge(refunds.transform_values(&:-@)) { |_, p, r| p + r }
             .sort_by { |year, _| -year }.to_h
  end
end
