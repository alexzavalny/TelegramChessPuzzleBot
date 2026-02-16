# frozen_string_literal: true

require 'cgi'

module TelegramChessPuzzleBot
  class Bot
    START_REGEX = %r{(?:^|\s)/?start(?:@[A-Za-z0-9_]+)?(?:\s|$)}i
    TRIGGER_REGEX = %r{(?:^|\s)/?puzzle(?:@[A-Za-z0-9_]+)?(?:\s|$)}i
    RANDOM_REGEX = %r{(?:^|\s)/?random(?:@[A-Za-z0-9_]+)?(?:\s|$)}i
    RANDOM_EASY_REGEX = %r{(?:^|\s)/?random-easy(?:@[A-Za-z0-9_]+)?(?:\s|$)}i
    RANDOM_HARD_REGEX = %r{(?:^|\s)/?random-hard(?:@[A-Za-z0-9_]+)?(?:\s|$)}i
    RANDOM_HARDEST_REGEX = %r{(?:^|\s)/?random-hardest(?:@[A-Za-z0-9_]+)?(?:\s|$)}i
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
        send_puzzle(client, chat_id, source: :random, difficulty: 'easier')
      elsif text.match?(RANDOM_HARD_REGEX)
        puts "[#{Time.now}] Random-hard command in chat=#{chat_id}. Preparing random puzzle."
        send_puzzle(client, chat_id, source: :random, difficulty: 'harder')
      elsif text.match?(RANDOM_HARDEST_REGEX)
        puts "[#{Time.now}] Random-hardest command in chat=#{chat_id}. Preparing random puzzle."
        send_puzzle(client, chat_id, source: :random, difficulty: 'hardest')
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
      reply_to_message_id = message.respond_to?(:message_id) ? message.message_id : nil
      session = @session_store.get(chat_id)
      return unless session

      input_moves = @answer_checker.parse_moves(text)
      if input_moves.empty?
        sent = send_reply_message(
          client,
          chat_id: chat_id,
          text: 'Send one move like: e2e4',
          reply_to_message_id: reply_to_message_id
        )
        track_reply_message(chat_id: chat_id, user_id: message.from&.id || 0, sent_message: sent, keep_only_latest: false)
        return
      end

      user_name = display_name_for(message.from)
      user_id = message.from&.id || 0
      outcome = nil
      @session_store.update(chat_id) do |s|
        progress = s.progress_by_user[user_id].to_i
        progress = 0 if progress >= s.puzzle.solution.length

        entry = s.scores[user_id] ||= { 'name' => user_name, 'correct_moves' => 0, 'solved_count' => 0 }
        entry['name'] = user_name
        accepted_moves = []
        opponent_moves = []
        wrong_move = nil

        input_moves.each do |input_move|
          expected_move = s.puzzle.solution[progress]
          result = @answer_checker.check_turn(input_move, expected_move)
          puts "[#{Time.now}] Answer checked chat=#{chat_id} user=#{user_id} correct=#{result.correct} input=#{input_move.inspect} expected=#{expected_move}"

          unless result.correct
            wrong_move = input_move
            break
          end

          entry['correct_moves'] += 1
          accepted_moves << input_move
          progress += 1

          break if progress >= s.puzzle.solution.length

          bot_move = s.puzzle.solution[progress]
          if bot_move
            opponent_moves << bot_move
            progress += 1
          end

          break if progress >= s.puzzle.solution.length
        end

        if accepted_moves.empty? && wrong_move
          outcome = { type: :wrong, message: 'Wrong move. Try again.' }
          next
        end

        line_complete = progress >= s.puzzle.solution.length
        if line_complete
          entry['solved_count'] += 1
          s.progress_by_user[user_id] = 0
        else
          s.progress_by_user[user_id] = progress
        end

        outcome = {
          type: :processed,
          accepted_count: accepted_moves.length,
          opponent_moves: opponent_moves,
          line_complete: line_complete,
          wrong_move: wrong_move
        }
      end

      session = @session_store.get(chat_id)
      case outcome && outcome[:type]
      when :wrong
        sent = send_reply_message(
          client,
          chat_id: chat_id,
          text: outcome[:message],
          reply_to_message_id: reply_to_message_id
        )
        track_reply_message(chat_id: chat_id, user_id: user_id, sent_message: sent, keep_only_latest: false)
      when :processed
        scoreboard = CGI.escapeHTML(scoreboard_text(session))
        base = "Accepted #{outcome[:accepted_count]} move#{outcome[:accepted_count] == 1 ? '' : 's'}."
        opponent_line = if outcome[:opponent_moves].any?
                          escaped = CGI.escapeHTML(outcome[:opponent_moves].join(' '))
                          "\nOpponent replies: <tg-spoiler>#{escaped}</tg-spoiler>."
                        else
                          ''
                        end
        status_line =
          if outcome[:line_complete]
            "\nLine complete. You solved it."
          elsif outcome[:wrong_move]
            "\nThen wrong move: <tg-spoiler>#{CGI.escapeHTML(outcome[:wrong_move])}</tg-spoiler>. Your turn from the current position."
          else
            "\nYour turn."
          end
        sent = send_reply_message(
          client,
          chat_id: chat_id,
          text: "#{base}#{opponent_line}#{status_line}\n#{scoreboard}",
          parse_mode: 'HTML',
          reply_to_message_id: reply_to_message_id
        )
        stale_message_ids = track_reply_message(
          chat_id: chat_id,
          user_id: user_id,
          sent_message: sent,
          keep_only_latest: outcome[:line_complete]
        )
        delete_messages(client, chat_id: chat_id, message_ids: stale_message_ids)
      end
      puts "[#{Time.now}] Session kept active for chat=#{chat_id}"
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
        "- random-easy: get a random Lichess puzzle (difficulty: easier)",
        "- random-hard: get a random Lichess puzzle (difficulty: harder)",
        "- random-hardest: get a random Lichess puzzle (difficulty: hardest)",
        "- answer: reveal the full solution for current puzzle",
        "",
        "How to solve:",
        "- Reply with one or more UCI moves: e2e4 or e2e4 g1f3",
        "- Bot will auto-play the opponent move in the line",
        "- In groups, each user has independent line progress",
        "- Scoreboard tracks correct user moves for current puzzle",
        "",
        "Works in DM and group chats."
      ].join("\n")
      client.api.send_message(chat_id: chat_id, text: msg)
    end

    def scoreboard_text(session)
      entries = session.scores.values.sort_by { |row| -row['correct_moves'] }
      solved_entries = entries.select { |row| row['solved_count'].to_i.positive? }
      solved_line = if solved_entries.empty?
                      'Solved by: not solved yet'
                    else
                      "Solved by: " + solved_entries.map { |row| "#{row['name']} x#{row['solved_count']}" }.join(', ')
                    end
      return "#{solved_line}\nScoreboard: no correct moves yet." if entries.empty?

      score_line = "Scoreboard: " + entries.map { |row| "#{row['name']}: #{row['correct_moves']}" }.join(', ')
      "#{solved_line}\n#{score_line}"
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

    def send_reply_message(client, chat_id:, text:, reply_to_message_id:, parse_mode: nil)
      payload = { chat_id: chat_id, text: text }
      payload[:parse_mode] = parse_mode if parse_mode
      payload[:reply_to_message_id] = reply_to_message_id if reply_to_message_id
      client.api.send_message(**payload)
    end

    def track_reply_message(chat_id:, user_id:, sent_message:, keep_only_latest:)
      message_id = dig_value(sent_message, :message_id)
      return [] unless message_id

      stale_message_ids = []
      @session_store.update(chat_id) do |session|
        session.reply_message_ids_by_user ||= {}
        ids = session.reply_message_ids_by_user[user_id] ||= []
        stale_message_ids = ids.dup if keep_only_latest
        ids << message_id
        ids.replace([message_id]) if keep_only_latest
      end
      stale_message_ids
    end

    def delete_messages(client, chat_id:, message_ids:)
      message_ids.uniq.each do |message_id|
        client.api.delete_message(chat_id: chat_id, message_id: message_id)
      rescue StandardError => e
        puts "[#{Time.now}] Failed to delete message chat=#{chat_id} message_id=#{message_id}: #{e.class}: #{e.message}"
      end
    end
  end
end
