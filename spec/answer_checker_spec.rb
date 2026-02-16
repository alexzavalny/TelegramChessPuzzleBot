# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TelegramChessPuzzleBot::AnswerChecker do
  subject(:checker) { described_class.new }

  let(:expected_move) { 'f3g3' }

  it 'accepts expected turn move' do
    result = checker.check_turn('f3g3', expected_move)

    expect(result.correct).to be(true)
    expect(result.move).to eq('f3g3')
  end

  it 'parses multiple moves from one message' do
    moves = checker.parse_moves('f3g3, f2g3; g1f3')
    expect(moves).to eq(%w[f3g3 f2g3 g1f3])
  end

  it 'rejects wrong move' do
    result = checker.check_turn('f3f2', expected_move)

    expect(result.correct).to be(false)
    expect(result.message).to match(/Wrong move/i)
  end
end
