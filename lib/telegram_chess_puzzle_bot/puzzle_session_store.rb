# frozen_string_literal: true

module TelegramChessPuzzleBot
  class PuzzleSessionStore
    Session = Struct.new(
      :chat_id,
      :puzzle,
      :created_at,
      :progress_by_user,
      :scores,
      :reply_message_ids_by_user,
      :attempt_errors_by_user,
      keyword_init: true
    )

    def initialize
      @sessions = {}
      @mutex = Mutex.new
    end

    def put(chat_id, puzzle)
      @mutex.synchronize do
        @sessions[chat_id] = Session.new(
          chat_id: chat_id,
          puzzle: puzzle,
          created_at: Time.now.utc,
          progress_by_user: {},
          scores: {},
          reply_message_ids_by_user: {},
          attempt_errors_by_user: {}
        )
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

    def update(chat_id)
      @mutex.synchronize do
        session = @sessions[chat_id]
        return unless session

        yield session
        session
      end
    end
  end
end
