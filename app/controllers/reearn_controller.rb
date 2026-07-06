class ReearnController < ApplicationController
  def show
    @current_account = Account.current
    return unless @current_account

    @result = ReearnProgress.call(@current_account)
    @earned_by_game = AccountTrophy.where(earned: true)
                                   .includes(:account, trophy: :game)
                                   .group_by { |at| at.trophy.game_id }
  end
end
