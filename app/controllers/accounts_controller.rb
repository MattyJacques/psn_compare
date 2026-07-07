class AccountsController < ApplicationController
  def index
    @accounts = Account.order(current: :desc, label: :asc).includes(:sync_runs)
  end

  def new
    redirect_to accounts_path and return if Account.exists?

    @bare = true
    @label = nil
  end

  def create
    Accounts::Register.call(label: params.dig(:account, :label),
                            npsso: params.dig(:account, :npsso))
    redirect_to accounts_path, notice: "Account added. Use Sync now to pull its data."
  rescue PSN::AuthenticationError => e
    flash.now[:alert] = "PSN rejected the NPSSO token: #{e.message}"
    @label = params.dig(:account, :label)
    @bare = Account.none?
    render :new, status: :unprocessable_content
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.message
    @label = params.dig(:account, :label)
    @bare = Account.none?
    render :new, status: :unprocessable_content
  end

  def destroy
    Account.find(params[:id]).destroy!
    redirect_to accounts_path, notice: "Account removed."
  end

  def sync
    SyncAccountJob.perform_later(Account.find(params[:id]))
    redirect_to accounts_path, notice: "Sync queued."
  end

  def make_current
    Account.find(params[:id]).make_current!
    redirect_to accounts_path, notice: "Current account updated."
  end

  def reauth
    Account.find(params[:id]).reauthenticate!(params[:npsso])
    redirect_to accounts_path, notice: "Re-authenticated."
  rescue PSN::AuthenticationError => e
    redirect_to accounts_path, alert: "PSN rejected the NPSSO token: #{e.message}"
  end
end
