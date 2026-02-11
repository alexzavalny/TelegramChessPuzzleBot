# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TelegramChessPuzzleBot::BoardRenderer do
  it 'creates a png file' do
    renderer = described_class.new
    fen = '8/8/8/8/8/8/8/4K3 w - - 0 1'

    path = renderer.render_png(fen: fen, puzzle_id: 'spec')

    expect(File.exist?(path)).to be(true)
    expect(File.binread(path, 8)).to eq("\x89PNG\r\n\x1A\n".b)
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end
