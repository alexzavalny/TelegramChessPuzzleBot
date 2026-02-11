# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TelegramChessPuzzleBot::AnswerChecker do
  subject(:checker) { described_class.new }

  let(:solution) { %w[f3g3 f2g3 f8f1] }

  it 'accepts first move only' do
    result = checker.check('f3g3', solution)

    expect(result.correct).to be(true)
    expect(result.message).to match(/Correct first move/)
  end

  it 'accepts correct sequence prefix' do
    result = checker.check('f3g3 f2g3', solution)

    expect(result.correct).to be(true)
    expect(result.message).to match(/Correct so far/)
  end

  it 'rejects wrong move' do
    result = checker.check('f3f2', solution)

    expect(result.correct).to be(false)
  end
end
