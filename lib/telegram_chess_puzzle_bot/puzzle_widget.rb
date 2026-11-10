# frozen_string_literal: true

require 'json'

module TelegramChessPuzzleBot
  # Self-contained puzzle widget: the FEN and the full solution are baked
  # into the HTML, so moves are checked on the device with no server calls.
  module PuzzleWidget
    TEMPLATE = File.expand_path('widgets/puzzle_board.html', __dir__)
    PLACEHOLDER = '__PUZZLE_DATA__'

    def self.html(fen:, solution:, rating: nil, id: nil)
      File.read(TEMPLATE).sub(
        PLACEHOLDER,
        JSON.generate({ fen: fen, solution: solution, rating: rating, id: id })
      )
    end
  end
end
