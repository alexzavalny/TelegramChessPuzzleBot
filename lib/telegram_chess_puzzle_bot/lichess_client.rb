# frozen_string_literal: true

module TelegramChessPuzzleBot
  class LichessClient
    DAILY_PUZZLE_URI = URI('https://lichess.org/api/puzzle/daily')

    def initialize(http: Net::HTTP)
      @http = http
    end

    def fetch_daily_puzzle
      response = @http.get_response(DAILY_PUZZLE_URI)
      raise "Lichess API error: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  end
end
