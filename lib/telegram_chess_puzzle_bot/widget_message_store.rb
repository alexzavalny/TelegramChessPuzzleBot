# frozen_string_literal: true

require 'json'
require 'fileutils'

module TelegramChessPuzzleBot
  # Remembers which puzzle went into which widget message, on disk, so a
  # restart between sending a widget and solving it does not lose the mapping.
  class WidgetMessageStore
    def initialize(path: File.expand_path('../../data/widget_messages.json', __dir__))
      @path = path
      @mutex = Mutex.new
    end

    def add(message_id, id:, rating:, chat_id:)
      @mutex.synchronize do
        data = load
        data[message_id.to_s] = { 'id' => id, 'rating' => rating, 'chat_id' => chat_id }
        prune(data)
        save(data)
      end
    end

    # Returns {id:, rating:, chat_id:} or nil.
    def find(message_id)
      entry = @mutex.synchronize { load[message_id.to_s] }
      return nil unless entry

      { id: entry['id'], rating: entry['rating'], chat_id: entry['chat_id'] }
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

    # Keep the file small; old widgets are not solvable in practice anyway.
    def prune(data)
      return if data.size <= 200

      data.keys.first(data.size - 200).each { |key| data.delete(key) }
    end
  end
end
