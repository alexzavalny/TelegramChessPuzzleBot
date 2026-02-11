# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TelegramChessPuzzleBot::FenBuilder do
  it 'builds fen after specified ply count' do
    pgn = 'e4 e5 Nf3 Nc6'
    fen = described_class.new.build(pgn: pgn, initial_ply: 3)

    expect(fen).to eq('r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3')
  end

  it 'handles castling and captures' do
    pgn = 'e4 e5 Nf3 Nc6 Bb5 a6 Bxc6 dxc6 O-O'
    fen = described_class.new.build(pgn: pgn, initial_ply: 8)

    expect(fen).to include(' b ')
    expect(fen.split.first).to include('K')
  end
end
