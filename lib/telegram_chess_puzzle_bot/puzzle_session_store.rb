# frozen_string_literal: true

module TelegramChessPuzzleBot
  class PuzzleSessionStore
    Session = Struct.new(:chat_id, :puzzle, :created_at, keyword_init: true)

    def initialize
      @sessions = {}
      @mutex = Mutex.new
    end

    def put(chat_id, puzzle)
      @mutex.synchronize do
        @sessions[chat_id] = Session.new(chat_id: chat_id, puzzle: puzzle, created_at: Time.now.utc)
      end
    end

    def get(chat_id)
      @mutex.synchronize { @sessions[chat_id] }
    end

    def delete(chat_id)
      @mutex.synchronize { @sessions.delete(chat_id) }
    end

    def pending?(chat_id)
      @mutex.synchronize { @sessions.key?(chat_id) }
    end
  end
end
