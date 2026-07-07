class TrophySkipsController < ApplicationController
  def create
    trophy = Trophy.find(params[:trophy_id])
    TrophySkip.find_or_create_by!(trophy:)
    redirect_back fallback_location: reearn_path
  end

  def destroy
    TrophySkip.find_by(trophy_id: params[:trophy_id])&.destroy!
    redirect_back fallback_location: reearn_path
  end
end
