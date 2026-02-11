# frozen_string_literal: true

module TelegramChessPuzzleBot
  DailyPuzzle = Struct.new(
    :id,
    :rating,
    :themes,
    :solution,
    :initial_ply,
    :game_id,
    :pgn,
    :fen,
    :side_to_move,
    keyword_init: true
  )

  module DailyPuzzleBuilder
    module_function

    def from_api(payload, fen:)
      puzzle = payload.fetch('puzzle')
      game = payload.fetch('game')

      DailyPuzzle.new(
        id: puzzle.fetch('id'),
        rating: puzzle.fetch('rating'),
        themes: puzzle.fetch('themes', []),
        solution: puzzle.fetch('solution').map(&:downcase),
        initial_ply: puzzle.fetch('initialPly'),
        game_id: game.fetch('id'),
        pgn: game.fetch('pgn'),
        fen: fen,
        side_to_move: fen.split[1]
      )
    end
  end
end
