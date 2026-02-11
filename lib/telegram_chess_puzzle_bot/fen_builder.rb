# frozen_string_literal: true

module TelegramChessPuzzleBot
  class FenBuilder
    def build(pgn:, initial_ply:)
      moves = extract_san_moves(pgn)
      position = ChessPosition.new

      # Lichess puzzle `initialPly` is zero-based.
      # To get the board shown in the puzzle, apply `initialPly + 1` plies.
      plies_to_apply = initial_ply.to_i + 1
      moves.first(plies_to_apply).each { |san| position.apply_san(san) }

      position.fen
    end

    private

    def extract_san_moves(pgn)
      pgn.split
         .reject { |token| token.match?(/\A\d+\./) }
         .reject { |token| %w[1-0 0-1 1/2-1/2 *].include?(token) }
    end
  end
end
