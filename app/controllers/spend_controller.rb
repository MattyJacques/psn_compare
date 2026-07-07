class SpendController < ApplicationController
  def index
    @summaries = SpendSummary.call
    @biggest = SpendSummary.biggest_purchases
  end
end
