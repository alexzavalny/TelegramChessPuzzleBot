# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'time'

module TelegramChessPuzzleBot
  # Counts solved widget puzzles per user and keeps them on disk so a restart
  # does not lose the tally.
  class WidgetSolveStore
    def initialize(path: File.expand_path('../../data/widget_solves.json', __dir__))
      @path = path
      @mutex = Mutex.new
    end

    # Returns [total solved by this user, whether this puzzle was new].
    def record(chat_id:, user_id:, puzzle:, seconds:, rating: nil)
      @mutex.synchronize do
        data = load
        user = data[user_id.to_s] ||= { 'chats' => [], 'solved' => {}, 'count' => 0 }
        user['chats'] |= [chat_id.to_s]
        return [user['count'], false] if user['solved'].key?(puzzle)

        user['solved'][puzzle] = {
          'seconds' => seconds.round(1),
          'rating' => rating,
          'at' => Time.now.utc.iso8601
        }
        user['count'] = user['solved'].size
        save(data)
        [user['count'], true]
      end
    end

    def count(user_id)
      @mutex.synchronize { (load[user_id.to_s] || { 'count' => 0 })['count'] }
    end

    private

    def load
      return {} unless File.exist?(@path)

      JSON.parse(File.read(@path))
    rescue JSON::ParserError
      {}
    end

    def save(data)
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, JSON.pretty_generate(data))
    end
  end
end
