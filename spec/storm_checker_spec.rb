# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TelegramChessPuzzleBot::StormChecker do
  class StormHttpStub
    def initialize(responses)
      @responses = responses
    end

    def get_response(uri)
      username = uri.path.split('/').last
      body = JSON.dump(@responses.fetch(username))
      Net::HTTPOK.new('1.1', '200', 'OK').tap do |response|
        response.instance_variable_set(:@body, body)
        response.define_singleton_method(:body) { @body }
      end
    end
  end

  it 'detects whether a player has a storm run today' do
    client = TelegramChessPuzzleBot::LichessClient.new(http: StormHttpStub.new(
      'DoneUser' => { 'days' => [{ '_id' => '2026/7/22', 'runs' => 1, 'score' => 10 }] },
      'MissingUser' => { 'days' => [] }
    ))

    results = described_class.new(lichess_client: client, today: Date.new(2026, 7, 22)).check(%w[DoneUser MissingUser])

    expect(results.map(&:username)).to eq(%w[DoneUser MissingUser])
    expect(results[0].done).to eq(true)
    expect(results[1].done).to eq(false)
  end
end
