# frozen_string_literal: true

module TelegramChessPuzzleBot
  class StormReminderState
    def initialize(path: File.expand_path('../../tmp/storm_reminder_state.json', __dir__))
      @path = path
    end

    def load
      return {} unless File.exist?(@path)

      JSON.parse(File.read(@path))
    rescue JSON::ParserError
      {}
    end

    def save(state)
      FileUtils.mkdir_p(File.dirname(@path))
      tmp_path = "#{@path}.tmp"
      File.write(tmp_path, JSON.pretty_generate(state))
      File.rename(tmp_path, @path)
    end

    def for_date(date)
      state = load
      key = date.iso8601
      state = { 'date' => key, 'praised' => [], 'all_done_announced' => false } unless state['date'] == key
      state
    end
  end
end
