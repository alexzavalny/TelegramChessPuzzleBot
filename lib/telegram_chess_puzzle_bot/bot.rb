# frozen_string_literal: true

module TelegramChessPuzzleBot
  class Bot
    TRIGGER_REGEX = /(?:^|\s)\/?puzzle(?:\s|$)/i

    def initialize(token:, lichess_client: LichessClient.new, fen_builder: FenBuilder.new, board_renderer: BoardRenderer.new,
                   answer_checker: AnswerChecker.new, session_store: PuzzleSessionStore.new)
      @token = token
      @lichess_client = lichess_client
      @fen_builder = fen_builder
      @board_renderer = board_renderer
      @answer_checker = answer_checker
      @session_store = session_store
    end

    def start
      Telegram::Bot::Client.run(@token) do |client|
        client.listen do |message|
          handle_message(client, message)
        rescue StandardError => e
          client.api.send_message(chat_id: message.chat.id, text: "Error: #{e.message}")
        end
      end
    end

    private

    def handle_message(client, message)
      return unless message.respond_to?(:text) && message.text

      chat_id = message.chat.id
      text = message.text.strip

      if text.match?(TRIGGER_REGEX)
        send_daily_puzzle(client, chat_id)
      elsif @session_store.pending?(chat_id)
        check_answer(client, chat_id, text)
      end
    end

    def send_daily_puzzle(client, chat_id)
      payload = @lichess_client.fetch_daily_puzzle
      fen = @fen_builder.build(
        pgn: payload.fetch('game').fetch('pgn'),
        initial_ply: payload.fetch('puzzle').fetch('initialPly')
      )
      puzzle = DailyPuzzleBuilder.from_api(payload, fen: fen)

      image_path = @board_renderer.render_png(fen: puzzle.fen, puzzle_id: puzzle.id)
      @session_store.put(chat_id, puzzle)

      file = UploadIO.new(image_path, 'image/png', File.basename(image_path))
      client.api.send_photo(
        chat_id: chat_id,
        photo: file,
        caption: caption_for(puzzle)
      )
    ensure
      File.delete(image_path) if image_path && File.exist?(image_path)
    end

    def check_answer(client, chat_id, text)
      session = @session_store.get(chat_id)
      return unless session

      result = @answer_checker.check(text, session.puzzle.solution)
      client.api.send_message(chat_id: chat_id, text: result.message)
      @session_store.delete(chat_id)
    end

    def caption_for(puzzle)
      themes = puzzle.themes.first(3).join(', ')
      "Daily Puzzle ##{puzzle.id} (#{puzzle.rating})\nThemes: #{themes}\nReply with UCI moves like: #{puzzle.solution.first}"
    end
  end
end
