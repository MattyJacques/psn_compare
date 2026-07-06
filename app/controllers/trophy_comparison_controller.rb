class TrophyComparisonController < ApplicationController
  def index
    @accounts = Account.order(current: :desc, label: :asc)
    @games = Game.joins(:account_games).distinct.order(:name).includes(:account_games)
  end
end
