# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module TelegramChessPuzzleBot
  # Thin raw-HTTP client for Bot API methods that telegram-bot-ruby 2.1
  # does not know about yet (for example sendWidget from Bot API 10.4).
  class TelegramApi
    class Error < StandardError; end

    def initialize(token)
      @token = token
    end

    def call(method, payload)
      uri = URI("https://api.telegram.org/bot#{@token}/#{method}")
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = JSON.generate(payload)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 20) do |http|
        http.request(request)
      end

      body = JSON.parse(response.body.to_s)
      raise Error, body['description'] || "HTTP #{response.code}" unless body['ok']

      body['result']
    rescue JSON::ParserError
      raise Error, "invalid response from #{method} (HTTP #{response&.code})"
    end

    # Long polling. Returns raw update hashes so widget_query payloads are
    # not dropped by telegram-bot-ruby's typed Update struct.
    def get_updates(offset:, timeout: 20)
      uri = URI("https://api.telegram.org/bot#{@token}/getUpdates")
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = JSON.generate(
        offset: offset,
        timeout: timeout,
        allowed_updates: %w[message edited_message callback_query inline_query widget_query shared_widget_query]
      )

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: timeout + 15) do |http|
        http.request(request)
      end

      body = JSON.parse(response.body.to_s)
      raise Error, body['description'] || "HTTP #{response.code}" unless body['ok']

      body['result']
    rescue JSON::ParserError
      raise Error, 'invalid response from getUpdates'
    end
  end
end
