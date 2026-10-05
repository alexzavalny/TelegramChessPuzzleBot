# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'json'

module TelegramChessPuzzleBot
  class StormCupTracker
    DEFAULT_PATH = File.expand_path('../../tmp/storm_cups.json', __dir__)

    def initialize(path: DEFAULT_PATH)
      @path = path
    end

    def record_daily_winners(date:, results:)
      winners = daily_winners(results)
      return [] if winners.empty?

      state = load
      state['days'] ||= {}
      state['days'][date.iso8601] = {
        'score' => winners.first.day.fetch('score', 0).to_i,
        'winners' => winners.map { |result| result.username }
      }
      save(state)
      winners.map(&:username)
    end

    def current_winner_names(results)
      daily_winners(results).map { |result| StormReport.display_name_for(result.username) }
    end

    def weekly_counts(date: Date.today)
      state = load
      days = state.fetch('days', {})
      week_dates(date).each_with_object(Hash.new(0)) do |day, counts|
        entry = days[day.iso8601]
        next unless entry

        Array(entry['winners']).each { |username| counts[username] += 1 }
      end
    end

    def weekly_report(date: Date.today)
      counts = weekly_counts(date: date)
      if counts.empty?
        return '🏆 Кубки Puzzle Storm за неделю: пока нет записей.'
      end

      lines = ['🏆 **Кубки Puzzle Storm за неделю:**']
      counts.sort_by { |username, count| [-count, StormReport.display_name_for(username)] }.each do |username, count|
        lines << "#{StormReport.escape(StormReport.display_name_for(username))} — #{count} #{cup_word(count)}"
      end
      lines.join("\n")
    end

    private

    def daily_winners(results)
      done = results.select(&:done)
      return [] if done.empty?

      max_score = done.map { |result| result.day.fetch('score', 0).to_i }.max
      done.select { |result| result.day.fetch('score', 0).to_i == max_score }
          .sort_by { |result| StormReport.display_name_for(result.username) }
    end

    def week_dates(date)
      start = date - (date.cwday - 1)
      (0..6).map { |offset| start + offset }
    end

    def cup_word(count)
      return 'кубок' if count % 10 == 1 && count % 100 != 11
      return 'кубка' if [2, 3, 4].include?(count % 10) && ![12, 13, 14].include?(count % 100)

      'кубков'
    end

    def load
      return {} unless File.exist?(@path)

      JSON.parse(File.read(@path))
    rescue JSON::ParserError
      {}
    end

    def save(state)
      FileUtils.mkdir_p(File.dirname(@path))
      tmp_path = "#{@path}.tmp"
      File.write(tmp_path, JSON.pretty_generate(state))
      File.rename(tmp_path, @path)
    end
  end
end
