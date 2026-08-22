# frozen_string_literal: true

require 'cgi'

module TelegramChessPuzzleBot
  module StormReport
    module_function

    def mentions_from_env(default_mentions = {})
      default_mentions.merge(
        ENV.fetch('STORM_REMINDER_MENTIONS', '').split(',').each_with_object({}) do |pair, map|
          lichess, telegram = pair.split('=', 2).map { |part| part.to_s.strip }
          map[lichess] = telegram if lichess && !lichess.empty? && telegram && !telegram.empty?
        end
      )
    end

    def mention_for(username, mentions)
      mention = mentions[username] || mentions[username.downcase]
      return escape(username) if mention.to_s.strip.empty?

      escape(mention)
    end

    def day_value(day, key)
      day.fetch(key, 0)
    end

    def done_rows(results)
      results.sort_by { |r| -r.day.fetch('score', 0).to_i }.map do |result|
        day = result.day
        [
          result.username,
          day_value(day, 'score'),
          day_value(day, 'runs'),
          day_value(day, 'highest'),
          day_value(day, 'combo'),
          day_value(day, 'errors')
        ]
      end
    end

    def done_markdown_table(results)
      rows = done_rows(results).map do |username, score, runs, highest, combo, errors|
        "| #{escape(username)} | #{score} | #{runs} | #{highest} | #{combo} | #{errors} |"
      end

      ([
        '| Игрок | Score | Runs | Highest | Combo | Errors |',
        '|---|---:|---:|---:|---:|---:|'
      ] + rows).join("\n")
    end

    def done_rich_table(results)
      header = %w[Игрок Score Runs Highest Combo Errors]
      rows = done_rows(results)
      cells = ([header] + rows).each_with_index.map do |row, row_index|
        row.each_with_index.map do |value, col_index|
          cell = { text: value.to_s, align: col_index.zero? ? 'left' : 'right', valign: 'middle' }
          cell[:is_header] = true if row_index.zero?
          cell
        end
      end

      { type: 'table', cells: cells, is_bordered: true, is_striped: true }
    end

    def rich_status(results, mentions, silent_usernames: [])
      silent = silent_usernames.map(&:downcase)
      done = results.select(&:done).sort_by { |r| -r.day.fetch('score', 0).to_i }
      missing = results.reject { |r| r.done || r.error || silent.include?(r.username.downcase) }
      errors = results.select(&:error)
      blocks = [{ type: 'paragraph', text: ['⚡ ', { type: 'bold', text: 'Puzzle Storm сегодня:' }] }]

      if done.empty?
        blocks << { type: 'paragraph', text: 'Пока никто не сделал.' }
      else
        blocks << done_rich_table(done)
      end

      unless missing.empty?
        blocks << { type: 'paragraph', text: ['⏰ ', { type: 'bold', text: 'Ещё ждём:' }] }
        missing.each { |result| blocks << { type: 'paragraph', text: "#{mention_for(result.username, mentions)} — пора на Lichess Storm ⚡" } }
      end

      unless errors.empty?
        blocks << { type: 'paragraph', text: '⚠️ Не смог проверить:' }
        errors.each { |result| blocks << { type: 'paragraph', text: "#{result.username} — #{result.error.message}" } }
      end

      { blocks: blocks }
    end

    def manual_status(results, mentions, silent_usernames: [])
      silent = silent_usernames.map(&:downcase)
      done = results.select(&:done).sort_by { |r| -r.day.fetch('score', 0).to_i }
      missing = results.reject { |r| r.done || r.error || silent.include?(r.username.downcase) }
      errors = results.select(&:error)
      lines = ['⚡ **Puzzle Storm сегодня:**']

      if done.empty?
        lines << 'Пока никто не сделал.'
      else
        lines << done_markdown_table(done)
      end

      unless missing.empty?
        lines << ''
        lines << '⏰ **Ещё ждём:**'
        missing.each { |result| lines << "#{mention_for(result.username, mentions)} — пора на Lichess Storm ⚡" }
      end

      unless errors.empty?
        lines << ''
        lines << '⚠️ Не смог проверить:'
        errors.each { |result| lines << "#{escape(result.username)} — #{escape(result.error.message)}" }
      end

      lines.join("\n")
    end

    def escape(text)
      CGI.escapeHTML(text.to_s)
    end
  end
end
