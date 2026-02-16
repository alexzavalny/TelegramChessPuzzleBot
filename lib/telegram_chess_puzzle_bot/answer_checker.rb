# frozen_string_literal: true

module TelegramChessPuzzleBot
  class AnswerChecker
    Result = Struct.new(:correct, :message, :move, keyword_init: true)

    def check_turn(input_text, expected_move)
      moves = parse_moves(input_text)
      return Result.new(correct: false, message: 'Send one move like: e2e4') if moves.empty?
      return Result.new(correct: false, message: 'Send one move at a time (example: e2e4).') if moves.length > 1

      move = moves.first
      if move == expected_move
        Result.new(correct: true, message: 'Correct.', move: move)
      else
        Result.new(correct: false, message: 'Wrong move. Try again.', move: move)
      end
    end

    def parse_moves(input_text)
      input_text.to_s
                .downcase
                .strip
                .split(/[\s,;]+/)
                .map { |token| token.gsub(/[^a-h1-8qrbn]/, '') }
                .select { |token| token.match?(/\A[a-h][1-8][a-h][1-8][qrbn]?\z/) }
    end
  end
end
