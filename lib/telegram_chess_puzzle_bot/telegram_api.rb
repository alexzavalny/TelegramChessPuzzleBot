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
  end
end
