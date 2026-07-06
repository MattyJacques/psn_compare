class OwnershipController < ApplicationController
  def index
    @accounts = Account.order(:label)
    @rows = OwnershipMatrix.call(include_dlc: params[:include_dlc].present?)
  end
end
