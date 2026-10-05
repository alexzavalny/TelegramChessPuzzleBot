# frozen_string_literal: true

require 'tmpdir'
require 'telegram_chess_puzzle_bot/storm_checker'
require 'telegram_chess_puzzle_bot/storm_cup_tracker'
require 'telegram_chess_puzzle_bot/storm_report'

RSpec.describe TelegramChessPuzzleBot::StormCupTracker do
  def result(username, score)
    TelegramChessPuzzleBot::StormChecker::Result.new(username: username, done: true, day: { 'score' => score, 'runs' => 1, 'highest' => 1400, 'combo' => 10, 'errors' => 0 })
  end

  it 'records the daily top scorer as a cup winner' do
    Dir.mktmpdir do |dir|
      tracker = described_class.new(path: File.join(dir, 'cups.json'))

      winners = tracker.record_daily_winners(
        date: Date.new(2026, 10, 5),
        results: [result('AlexIsNot', 25), result('TheErix', 31)]
      )

      expect(winners).to eq(['TheErix'])
      expect(tracker.weekly_counts(date: Date.new(2026, 10, 11))).to eq('TheErix' => 1)
    end
  end

  it 'keeps tied first places for the day' do
    Dir.mktmpdir do |dir|
      tracker = described_class.new(path: File.join(dir, 'cups.json'))

      winners = tracker.record_daily_winners(
        date: Date.new(2026, 10, 5),
        results: [result('AlexIsNot', 31), result('TheErix', 31)]
      )

      expect(winners).to eq(%w[AlexIsNot TheErix])
      expect(tracker.weekly_counts(date: Date.new(2026, 10, 11))).to eq('AlexIsNot' => 1, 'TheErix' => 1)
    end
  end

  it 'formats weekly report by cup count' do
    Dir.mktmpdir do |dir|
      tracker = described_class.new(path: File.join(dir, 'cups.json'))
      tracker.record_daily_winners(date: Date.new(2026, 10, 5), results: [result('AlexIsNot', 31)])
      tracker.record_daily_winners(date: Date.new(2026, 10, 6), results: [result('TheErix', 30)])
      tracker.record_daily_winners(date: Date.new(2026, 10, 7), results: [result('AlexIsNot', 35)])

      report = tracker.weekly_report(date: Date.new(2026, 10, 11))

      expect(report).to include('Alex Z — 2 кубка')
      expect(report).to include('Erik G — 1 кубок')
    end
  end
end
