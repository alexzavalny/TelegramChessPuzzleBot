# frozen_string_literal: true

require 'telegram_chess_puzzle_bot/storm_report'

RSpec.describe TelegramChessPuzzleBot::StormReport do
  Result = TelegramChessPuzzleBot::StormChecker::Result

  it 'formats done users as a markdown table' do
    results = [
      Result.new(username: 'AlexIsNot', done: true, day: { 'score' => 30, 'runs' => 3, 'highest' => 1468, 'combo' => 56, 'errors' => 2 }),
      Result.new(username: 'Jefimser', done: true, day: { 'score' => 29, 'runs' => 2, 'highest' => 1465, 'combo' => 34, 'errors' => 2 })
    ]

    text = described_class.manual_status(results, {})

    expect(text).to include('| Игрок | Score | Runs | Highest | Combo | Errors |')
    expect(text).to include('| AlexIsNot | 30 | 3 | 1468 | 56 | 2 |')
    expect(text).to include('| Jefimser | 29 | 2 | 1465 | 34 | 2 |')
  end
end
