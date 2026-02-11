# frozen_string_literal: true

module TelegramChessPuzzleBot
  class AnswerChecker
    Result = Struct.new(:correct, :message, :completed, keyword_init: true)

    def check(input_text, solution)
      moves = parse_input_moves(input_text)
      return Result.new(correct: false, message: 'Send moves like: f3g3 or f3g3 f2g3', completed: false) if moves.empty?

      if prefix_match?(moves, solution)
        complete = moves.length == solution.length
        msg = if complete
                'Correct sequence.'
              elsif moves.length == 1
                'Correct first move. Send next move.'
              else
                'Correct so far. Send next move.'
              end
        Result.new(correct: true, message: msg, completed: complete)
      else
        Result.new(correct: false, message: 'Wrong move sequence.', completed: false)
      end
    end

    private

    def parse_input_moves(input_text)
      input_text.to_s
                .downcase
                .strip
                .split(/[\s,;]+/)
                .map { |token| token.gsub(/[^a-h1-8qrbn]/, '') }
                .select { |token| token.match?(/\A[a-h][1-8][a-h][1-8][qrbn]?\z/) }
    end

    def prefix_match?(moves, solution)
      return false if moves.length > solution.length

      moves.each_with_index.all? { |mv, idx| mv == solution[idx] }
    end
  end
end
