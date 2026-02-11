# frozen_string_literal: true

module TelegramChessPuzzleBot
  class AnswerChecker
    Result = Struct.new(:correct, :message, keyword_init: true)

    def check(input_text, solution)
      moves = parse_input_moves(input_text)
      return Result.new(correct: false, message: 'Send moves like: f3g3 or f3g3 f2g3') if moves.empty?

      if prefix_match?(moves, solution)
        msg = if moves.length == 1
                'Correct first move.'
              elsif moves.length == solution.length
                'Correct sequence.'
              else
                'Correct so far.'
              end
        Result.new(correct: true, message: msg)
      else
        Result.new(correct: false, message: 'Wrong move sequence.')
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
