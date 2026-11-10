# frozen_string_literal: true

module TelegramChessPuzzleBot
  # Static HTML for the experimental /test board widget.
  # Self-contained: inline CSS/JS, inline SVG pieces, no network access.
  module TestBoardWidget
    PATH = File.expand_path('widgets/test_board.html', __dir__)

    def self.html
      File.read(PATH)
    end
  end
end
