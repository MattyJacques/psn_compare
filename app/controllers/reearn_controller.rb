class ReearnController < ApplicationController
  GAME_FILTERS = %w[owned platinum skipped].freeze
  BACKLOG_SORTS = %w[common rare].freeze
  BACKLOG_FILTERS = %w[platinum owned skipped].freeze

  def show
    return unless (@main = Account.current)

    @result = ReearnProgress.call(@main)
    @ownership = MainOwnership.call(@main)
    @filter = params[:filter].presence_in(GAME_FILTERS)
    @skipped_total = @result.games.sum(&:skipped)
    @games = filtered_games
  end

  def backlog
    return unless (@main = Account.current)

    @sort = params[:sort].presence_in(BACKLOG_SORTS) || "common"
    @filter = params[:filter].presence_in(BACKLOG_FILTERS)
    @rows = ReearnBacklog.call(@main, sort: @sort, filter: @filter)
    @to_go = @filter ? ReearnBacklog.call(@main).size : @rows.size
    @skipped_count = @filter == "skipped" ? @rows.size : ReearnBacklog.call(@main, filter: "skipped").size
  end

  private

  def filtered_games
    games = @result.games.reject(&:complete?)
    case @filter
    when "owned" then games.select { |gp| @ownership.owned?(gp.game) }
    when "platinum" then games.select { |gp| gp.missing.any? { |m| !m.skipped && m.trophy.trophy_type == "platinum" } }
    when "skipped" then @result.games.select { |gp| gp.skipped.positive? }
    else games
    end
  end
end
