# frozen_string_literal: true

module TelegramChessPuzzleBot
  class LichessClient
    DAILY_PUZZLE_URI = URI('https://lichess.org/api/puzzle/daily')
    RANDOM_PUZZLE_BASE_URI = URI('https://lichess.org/api/puzzle/next')
    STORM_DASHBOARD_BASE = 'https://lichess.org/api/storm/dashboard'

    def initialize(http: Net::HTTP)
      @http = http
    end

    def fetch_daily_puzzle
      response = @http.get_response(DAILY_PUZZLE_URI)
      raise "Lichess API error: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def fetch_random_puzzle(difficulty: 'normal')
      uri = RANDOM_PUZZLE_BASE_URI.dup
      uri.query = URI.encode_www_form(difficulty: difficulty)

      response = @http.get_response(uri)
      raise "Lichess API error: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def fetch_storm_dashboard(username, days: 1)
      uri = URI("#{STORM_DASHBOARD_BASE}/#{URI.encode_www_form_component(username)}")
      uri.query = URI.encode_www_form(days: days)

      response = @http.get_response(uri)
      raise "Lichess Storm API error for #{username}: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  end
end
