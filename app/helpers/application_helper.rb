module ApplicationHelper
  CURRENCY_SYMBOLS = { "GBP" => "£", "USD" => "$", "EUR" => "€" }.freeze

  # Minor units in, human string out. Assumes 2 minor-unit digits, which
  # holds for the currencies PSN bills in around here.
  def format_money(amount_minor, currency)
    return "—" if amount_minor.nil?

    value = format("%.2f", amount_minor.abs / 100.0)
    symbol = CURRENCY_SYMBOLS[currency]
    formatted = symbol ? "#{symbol}#{value}" : "#{value} #{currency}"
    amount_minor.negative? ? "-#{formatted}" : formatted
  end
end
