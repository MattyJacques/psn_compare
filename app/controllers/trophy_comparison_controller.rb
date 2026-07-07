class TrophyComparisonController < ApplicationController
  FILTERS = %w[missing skipped everywhere].freeze

  def index
    @accounts = Account.order(current: :desc, label: :asc)
    @main = Account.current
    @games = Game.joins(:trophies).distinct.order(:name)
    @game = @games.find_by(id: params[:game_id]) || @games.first
    @filter = params[:filter].presence_in(FILTERS)
    @q = params[:q].to_s.strip
    return unless @game

    trophies = @game.trophies.includes(:skip).order(:psn_trophy_id)
    trophies = trophies.where("name LIKE ?", "%#{Trophy.sanitize_sql_like(@q)}%") if @q.present?
    earned = AccountTrophy.where(trophy: trophies, earned: true).index_by { |at| [at.trophy_id, at.account_id] }
    @rows = trophies.map { |trophy| row_for(trophy, earned) }
    @counts = counts
    @rows = @rows.select { |r| visible?(r) }
  end

  private

  Row = Data.define(:trophy, :earned_by, :candidate) # earned_by: {account_id => AccountTrophy}

  def row_for(trophy, earned)
    earned_by = @accounts.filter_map { |a| [a.id, earned[[trophy.id, a.id]]] if earned[[trophy.id, a.id]] }.to_h
    candidate = @main && !trophy.skipped? && earned_by.any? && !earned_by.key?(@main.id)
    Row.new(trophy:, earned_by:, candidate:)
  end

  def counts
    all = @rows.size
    { all:, missing: @rows.count(&:candidate),
      skipped: @rows.count { |r| r.trophy.skipped? },
      everywhere: @rows.count { |r| r.earned_by.size == @accounts.size && @accounts.any? } }
  end

  def visible?(row)
    case @filter
    when "missing" then row.candidate
    when "skipped" then row.trophy.skipped?
    when "everywhere" then row.earned_by.size == @accounts.size
    else true
    end
  end
end
