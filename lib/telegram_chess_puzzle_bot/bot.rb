# frozen_string_literal: true

require 'cgi'

module TelegramChessPuzzleBot
  class Bot
    START_REGEX = %r{(?:^|\s)/?start(?:@[A-Za-z0-9_]+)?(?:\s|$)}i
    TRIGGER_REGEX = %r{(?:^|\s)/?puzzle(?:@[A-Za-z0-9_]+)?(?:\s|$)}i
    RANDOM_REGEX = %r{(?:^|\s)/?random(?:@[A-Za-z0-9_]+)?(?:\s|$)}i
    RANDOM_EASY_REGEX = %r{(?:^|\s)/?random-easy(?:@[A-Za-z0-9_]+)?(?:\s|$)}i
    RANDOM_HARD_REGEX = %r{(?:^|\s)/?random-hard(?:@[A-Za-z0-9_]+)?(?:\s|$)}i
    ANSWER_REGEX = %r{(?:^|\s)/?answer(?:@[A-Za-z0-9_]+)?(?:\s|$)}i

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
        me = client.api.get_me
        username = dig_value(me, :username)
        bot_id = dig_value(me, :id)
        puts "[#{Time.now}] Logged in as @#{username} (id=#{bot_id})"
        client.api.delete_webhook(drop_pending_updates: false)
        puts "[#{Time.now}] Webhook removed. Using long polling for updates."
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

      if text.match?(START_REGEX)
        puts "[#{Time.now}] Start/help command in chat=#{chat_id}."
        send_help(client, chat_id)
      elsif text.match?(TRIGGER_REGEX)
        puts "[#{Time.now}] Trigger detected in chat=#{chat_id}. Preparing daily puzzle."
        send_puzzle(client, chat_id, source: :daily)
      elsif text.match?(RANDOM_REGEX)
        puts "[#{Time.now}] Random command in chat=#{chat_id}. Preparing random puzzle."
        send_puzzle(client, chat_id, source: :random, difficulty: 'normal')
      elsif text.match?(RANDOM_EASY_REGEX)
        puts "[#{Time.now}] Random-easy command in chat=#{chat_id}. Preparing random puzzle."
        send_puzzle(client, chat_id, source: :random, difficulty: 'easy')
      elsif text.match?(RANDOM_HARD_REGEX)
        puts "[#{Time.now}] Random-hard command in chat=#{chat_id}. Preparing random puzzle."
        send_puzzle(client, chat_id, source: :random, difficulty: 'hard')
      elsif text.match?(ANSWER_REGEX)
        puts "[#{Time.now}] Answer command in chat=#{chat_id}."
        send_answer(client, chat_id)
      elsif @session_store.pending?(chat_id)
        puts "[#{Time.now}] Pending puzzle found for chat=#{chat_id}. Checking answer."
        check_answer(client, message)
      else
        puts "[#{Time.now}] Ignored message in chat=#{chat_id} (no trigger, no pending puzzle)."
      end
    end

    def send_puzzle(client, chat_id, source:, difficulty: nil)
      puts "[#{Time.now}] Fetching #{source} puzzle from Lichess..."
      payload = if source == :random
                  @lichess_client.fetch_random_puzzle(difficulty: difficulty || 'normal')
                else
                  @lichess_client.fetch_daily_puzzle
                end
      fen = @fen_builder.build(
        pgn: payload.fetch('game').fetch('pgn'),
        initial_ply: payload.fetch('puzzle').fetch('initialPly')
      )
      puzzle = DailyPuzzleBuilder.from_api(payload, fen: fen)
      puts "[#{Time.now}] Puzzle fetched id=#{puzzle.id} rating=#{puzzle.rating} side_to_move=#{puzzle.side_to_move}"

      image_path = @board_renderer.render_png(
        fen: puzzle.fen,
        puzzle_id: puzzle.id,
        flip_for_black: puzzle.side_to_move == 'b'
      )
      puts "[#{Time.now}] Board rendered: #{image_path}"
      @session_store.put(chat_id, puzzle)
      puts "[#{Time.now}] Session stored for chat=#{chat_id}"

      file = UploadIO.new(image_path, 'image/png', File.basename(image_path))
      client.api.send_photo(
        chat_id: chat_id,
        photo: file,
        caption: caption_for(puzzle, source: source, difficulty: difficulty)
      )
      puts "[#{Time.now}] Puzzle photo sent to chat=#{chat_id}"
    ensure
      File.delete(image_path) if image_path && File.exist?(image_path)
      puts "[#{Time.now}] Temp image deleted: #{image_path}" if image_path
    end

    def check_answer(client, message)
      chat_id = message.chat.id
      text = message.text.to_s.strip
      session = @session_store.get(chat_id)
      return unless session

      expected_move = session.puzzle.solution[session.progress]
      unless expected_move
        @session_store.update(chat_id) { |s| s.progress = 0 }
        client.api.send_message(chat_id: chat_id, text: 'Puzzle line was complete, reset to start. Your turn.')
        return
      end

      result = @answer_checker.check_turn(text, expected_move)
      puts "[#{Time.now}] Answer checked chat=#{chat_id} correct=#{result.correct} input=#{text.inspect} expected=#{expected_move}"
      unless result.correct
        client.api.send_message(chat_id: chat_id, text: result.message)
        puts "[#{Time.now}] Session kept active for chat=#{chat_id}"
        return
      end

      user_name = display_name_for(message.from)
      user_id = message.from&.id || 0

      @session_store.update(chat_id) do |s|
        entry = s.scores[user_id] ||= { 'name' => user_name, 'correct_moves' => 0 }
        entry['name'] = user_name
        entry['correct_moves'] += 1
        s.progress += 1
        if s.progress >= s.puzzle.solution.length
          s.solved_by ||= { 'id' => user_id, 'name' => user_name }
        end
      end

      session = @session_store.get(chat_id)
      if session.progress >= session.puzzle.solution.length
        client.api.send_message(chat_id: chat_id, text: "Correct. Puzzle solved.\n#{scoreboard_text(session)}\nLine reset, others can continue.")
        @session_store.update(chat_id) { |s| s.progress = 0 }
        puts "[#{Time.now}] Session kept active for chat=#{chat_id} (line reset after solve)"
        return
      end

      bot_move = nil
      @session_store.update(chat_id) do |s|
        bot_move = s.puzzle.solution[s.progress]
        s.progress += 1 if bot_move
        if s.progress >= s.puzzle.solution.length
          s.solved_by ||= { 'id' => user_id, 'name' => user_name }
        end
      end
      session = @session_store.get(chat_id)

      if session.progress >= session.puzzle.solution.length
        client.api.send_message(
          chat_id: chat_id,
          text: "Correct. Opponent plays <tg-spoiler>#{CGI.escapeHTML(bot_move.to_s)}</tg-spoiler>.\nLine complete.\n#{CGI.escapeHTML(scoreboard_text(session))}\nLine reset, others can continue.",
          parse_mode: 'HTML'
        )
        @session_store.update(chat_id) { |s| s.progress = 0 }
        puts "[#{Time.now}] Session kept active for chat=#{chat_id} (line reset after solve)"
      else
        client.api.send_message(
          chat_id: chat_id,
          text: "Correct. Opponent plays <tg-spoiler>#{CGI.escapeHTML(bot_move.to_s)}</tg-spoiler>. Your turn.\n#{CGI.escapeHTML(scoreboard_text(session))}",
          parse_mode: 'HTML'
        )
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
      client.api.send_message(
        chat_id: chat_id,
        text: "Solution: <tg-spoiler>#{CGI.escapeHTML(solution)}</tg-spoiler>\n#{CGI.escapeHTML(scoreboard_text(session))}",
        parse_mode: 'HTML'
      )
      @session_store.delete(chat_id)
      puts "[#{Time.now}] Solution revealed and session closed for chat=#{chat_id}"
    end

    def caption_for(puzzle, source:, difficulty:)
      title = if source == :random
                diff = difficulty.to_s.strip
                diff = 'normal' if diff.empty?
                "Random Puzzle (#{diff})"
              else
                'Daily Puzzle'
              end
      to_move = puzzle.side_to_move == 'w' ? 'White to move' : 'Black to move'
      "#{title} ##{puzzle.id} (#{puzzle.rating})\n#{to_move}\nReply with UCI moves like: e2e4"
    end

    def send_help(client, chat_id)
      msg = [
        "Chess Puzzle Bot",
        "",
        "Commands:",
        "- puzzle: get today's Lichess daily puzzle",
        "- random: get a random Lichess puzzle (difficulty: normal)",
        "- random-easy: get a random Lichess puzzle (difficulty: easy)",
        "- random-hard: get a random Lichess puzzle (difficulty: hard)",
        "- answer: reveal the full solution for current puzzle",
        "",
        "How to solve:",
        "- Reply with one UCI move at a time: e2e4",
        "- Bot will auto-play the opponent move in the line",
        "- Scoreboard tracks correct user moves for current puzzle",
        "",
        "Works in DM and group chats."
      ].join("\n")
      client.api.send_message(chat_id: chat_id, text: msg)
    end

    def scoreboard_text(session)
      entries = session.scores.values.sort_by { |row| -row['correct_moves'] }
      solved_line = if session.solved_by
                      "Solved by: #{session.solved_by['name']}"
                    else
                      'Solved by: not solved yet'
                    end
      return "#{solved_line}\nScoreboard: no correct moves yet." if entries.empty?

      "#{solved_line}\nScoreboard: " + entries.map { |row| "#{row['name']}: #{row['correct_moves']}" }.join(', ')
    end

    def display_name_for(user)
      return 'unknown' unless user

      return "@#{user.username}" if user.respond_to?(:username) && user.username && !user.username.empty?
      return user.first_name if user.respond_to?(:first_name) && user.first_name && !user.first_name.empty?

      "user_#{user.id}"
    end

    def dig_value(value, key)
      if value.respond_to?(key)
        value.public_send(key)
      elsif value.is_a?(Hash)
        value[key.to_s] || value[key.to_sym]
      elsif value.respond_to?(:[])
        value[key]
      end
    end
  end
end
