# frozen_string_literal: true

module TelegramChessPuzzleBot
  class Bot
    TRIGGER_REGEX = /(?:^|\s)\/?puzzle(?:\s|$)/i
    ANSWER_REGEX = /(?:^|\s)\/?answer(?:\s|$)/i

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
      puts "[#{Time.now}] Starting TelegramChessPuzzleBot..."
      Telegram::Bot::Client.run(@token) do |client|
        puts "[#{Time.now}] Bot connected. Waiting for messages."
        client.listen do |message|
          handle_message(client, message)
        rescue StandardError => e
          puts "[#{Time.now}] Error while handling message: #{e.class}: #{e.message}"
          puts e.backtrace.first(5).join("\n") if e.backtrace
          client.api.send_message(chat_id: message.chat.id, text: "Error: #{e.message}")
        end
      end
    end

    private

    def handle_message(client, message)
      return unless message.respond_to?(:text) && message.text

      chat_id = message.chat.id
      text = message.text.strip
      user = message.from&.username || message.from&.first_name || "unknown"
      puts "[#{Time.now}] Message chat=#{chat_id} user=#{user} text=#{text.inspect}"

      if text.match?(TRIGGER_REGEX)
        puts "[#{Time.now}] Trigger detected in chat=#{chat_id}. Preparing daily puzzle."
        send_daily_puzzle(client, chat_id)
      elsif text.match?(ANSWER_REGEX)
        puts "[#{Time.now}] Answer command in chat=#{chat_id}."
        send_answer(client, chat_id)
      elsif @session_store.pending?(chat_id)
        puts "[#{Time.now}] Pending puzzle found for chat=#{chat_id}. Checking answer."
        check_answer(client, chat_id, text)
      else
        puts "[#{Time.now}] Ignored message in chat=#{chat_id} (no trigger, no pending puzzle)."
      end
    end

    def send_daily_puzzle(client, chat_id)
      puts "[#{Time.now}] Fetching daily puzzle from Lichess..."
      payload = @lichess_client.fetch_daily_puzzle
      fen = @fen_builder.build(
        pgn: payload.fetch('game').fetch('pgn'),
        initial_ply: payload.fetch('puzzle').fetch('initialPly')
      )
      puzzle = DailyPuzzleBuilder.from_api(payload, fen: fen)
      puts "[#{Time.now}] Puzzle fetched id=#{puzzle.id} rating=#{puzzle.rating} side_to_move=#{puzzle.side_to_move}"

      image_path = @board_renderer.render_png(fen: puzzle.fen, puzzle_id: puzzle.id)
      puts "[#{Time.now}] Board rendered: #{image_path}"
      @session_store.put(chat_id, puzzle)
      puts "[#{Time.now}] Session stored for chat=#{chat_id}"

      file = UploadIO.new(image_path, 'image/png', File.basename(image_path))
      client.api.send_photo(
        chat_id: chat_id,
        photo: file,
        caption: caption_for(puzzle)
      )
      puts "[#{Time.now}] Puzzle photo sent to chat=#{chat_id}"
    ensure
      File.delete(image_path) if image_path && File.exist?(image_path)
      puts "[#{Time.now}] Temp image deleted: #{image_path}" if image_path
    end

    def check_answer(client, chat_id, text)
      session = @session_store.get(chat_id)
      return unless session

      result = @answer_checker.check(text, session.puzzle.solution)
      puts "[#{Time.now}] Answer checked chat=#{chat_id} correct=#{result.correct} input=#{text.inspect}"
      client.api.send_message(chat_id: chat_id, text: result.message)
      if result.completed
        @session_store.delete(chat_id)
        puts "[#{Time.now}] Session closed for chat=#{chat_id}"
      else
        puts "[#{Time.now}] Session kept active for chat=#{chat_id}"
      end
    end

    def send_answer(client, chat_id)
      session = @session_store.get(chat_id)
      unless session
        client.api.send_message(chat_id: chat_id, text: 'No active puzzle. Send puzzle first.')
        return
      end

      solution = session.puzzle.solution.join(' ')
      client.api.send_message(chat_id: chat_id, text: "Solution: #{solution}")
      @session_store.delete(chat_id)
      puts "[#{Time.now}] Solution revealed and session closed for chat=#{chat_id}"
    end

    def caption_for(puzzle)
      "Daily Puzzle ##{puzzle.id} (#{puzzle.rating})\nReply with UCI moves like: e2e4"
    end
  end
end
