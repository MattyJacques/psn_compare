module Sync
  class Transactions
    REFUND_TYPES = /refund|chargeback/i
    WALLET_TYPES = /wallet|fund|deposit|top.?up/i

    def self.call(account) = new(account).call

    def initialize(account)
      @account = account
    end

    def call
      count = 0
      @account.with_client do |client|
        client.store.transactions.each do |txn|
          next if txn.transaction_id.blank?

          @account.psn_transactions.find_or_initialize_by(psn_transaction_id: txn.transaction_id)
                  .update!(kind: kind_for(txn.type), amount_minor: txn.amount,
                           currency: txn.currency, occurred_at: txn.date,
                           description: txn.description, payment_method: txn.payment_method)
          count += 1
        end
      end
      count
    end

    private

    def kind_for(type)
      case type
      when REFUND_TYPES then "refund"
      when WALLET_TYPES then "wallet"
      else "purchase"
      end
    end
  end
end
