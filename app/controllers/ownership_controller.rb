class OwnershipController < ApplicationController
  FILTERS = %w[not_owned twice].freeze

  def index
    @main = Account.current
    @accounts = Account.order(current: :desc, label: :asc)
    @filter = params[:filter].presence_in(FILTERS)
    @q = params[:q].to_s.strip
    rows = OwnershipMatrix.call(include_dlc: params[:include_dlc].present?, main: @main)
    rows = rows.select { |r| r.name.to_s.downcase.include?(@q.downcase) } if @q.present?
    @played = @main ? @main.games.pluck(:name).map { |n| MainOwnership.normalize(n) }.reject(&:blank?) : []
    @rows = filtered(rows)
  end

  private

  def filtered(rows)
    case @filter
    when "not_owned" then rows.reject { |r| @main && owned_on_main?(r) }
    when "twice" then rows.select(&:duplicate?)
    else rows
    end
  end

  def owned_on_main?(row)
    row.by_account_id.key?(@main.id) ||
      @played.any? { |g| MainOwnership.normalize(row.name).start_with?(g) }
  end
end
