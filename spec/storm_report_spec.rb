# frozen_string_literal: true

require 'telegram_chess_puzzle_bot/storm_report'

RSpec.describe TelegramChessPuzzleBot::StormReport do
  Result = TelegramChessPuzzleBot::StormChecker::Result

  it 'formats done users as a markdown table with display names' do
    results = [
      Result.new(username: 'AlexIsNot', done: true, day: { 'score' => 30, 'runs' => 3, 'highest' => 1468, 'combo' => 56, 'errors' => 2 }),
      Result.new(username: 'Jefimser', done: true, day: { 'score' => 29, 'runs' => 2, 'highest' => 1465, 'combo' => 34, 'errors' => 2 })
    ]

    text = described_class.manual_status(results, {})

    expect(text).to include('| Игрок | Score | Runs | Highest | Combo | Errors |')
    expect(text).to include('| Alex Z | 30 | 3 | 1468 | 56 | 2 |')
    expect(text).to include('| Sergey J | 29 | 2 | 1465 | 34 | 2 |')
  end

  it 'formats rich table with display names' do
    results = [
      Result.new(username: 'TheErix', done: true, day: { 'score' => 31, 'runs' => 4, 'highest' => 1500, 'combo' => 60, 'errors' => 1 })
    ]

    rich = described_class.rich_status(results, {})
    table = rich.fetch(:blocks).find { |block| block[:type] == 'table' }

    expect(table.fetch(:cells).flatten).to include(hash_including(text: 'Erik G'))
  end

  it 'appends current cup holder to manual and rich status' do
    results = [
      Result.new(username: 'TheErix', done: true, day: { 'score' => 31, 'runs' => 4, 'highest' => 1500, 'combo' => 60, 'errors' => 1 })
    ]

    text = described_class.manual_status(results, {}, cup_winner_names: ['Erik G'])
    rich = described_class.rich_status(results, {}, cup_winner_names: ['Erik G'])

    expect(text).to include('Пока что 🏆 получает - Erik G')
    expect(rich.fetch(:blocks)).to include(hash_including(text: 'Пока что 🏆 получает - Erik G'))
  end
end
