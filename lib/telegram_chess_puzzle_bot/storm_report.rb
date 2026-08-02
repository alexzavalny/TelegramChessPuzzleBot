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

    def format_day(day)
      score = day.fetch('score', 0)
      runs = day.fetch('runs', 0)
      highest = day.fetch('highest', 0)
      combo = day.fetch('combo', 0)
      errors = day.fetch('errors', 0)
      "score #{score}, runs #{runs}, highest #{highest}, combo #{combo}, errors #{errors}"
    end

    def manual_status(results, mentions, silent_usernames: [])
      silent = silent_usernames.map(&:downcase)
      done = results.select(&:done).sort_by { |r| -r.day.fetch('score', 0).to_i }
      missing = results.reject { |r| r.done || r.error || silent.include?(r.username.downcase) }
      errors = results.select(&:error)
      lines = ['⚡ <b>Puzzle Storm сегодня:</b>']

      if done.empty?
        lines << 'Пока никто не сделал.'
      else
        done.each_with_index do |result, index|
          medal = %w[🥇 🥈 🥉][index] || '•'
          lines << "#{medal} #{mention_for(result.username, mentions)} — #{format_day(result.day)}"
        end
      end

      unless missing.empty?
        lines << ''
        lines << '⏰ <b>Ещё ждём:</b>'
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
