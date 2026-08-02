# frozen_string_literal: true

module TelegramChessPuzzleBot
  class StormChecker
    DATE_FORMAT = '%Y/%-m/%-d'

    Result = Struct.new(:username, :done, :day, :error, keyword_init: true)

    def initialize(lichess_client:, today: Date.today)
      @lichess_client = lichess_client
      @today = today
    end

    def check(usernames)
      usernames.map { |username| check_one(username) }
    end

    private

    def check_one(username)
      dashboard = @lichess_client.fetch_storm_dashboard(username, days: 1)
      today_key = @today.strftime(DATE_FORMAT)
      day = dashboard.fetch('days', []).find { |row| row['_id'] == today_key }
      Result.new(username: username, done: !!day && day.fetch('runs', 0).to_i.positive?, day: day)
    rescue StandardError => e
      Result.new(username: username, done: false, error: e)
    end
  end
end
