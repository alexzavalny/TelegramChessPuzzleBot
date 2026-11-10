# frozen_string_literal: true

require 'spec_helper'
require 'zlib'

RSpec.describe 'telegram widget test command' do
  FakeTelegramApi = Struct.new(:calls) do
    def call(method, payload)
      calls << [method, payload]
      { 'message_id' => 1 }
    end
  end

  MessagesApi = Struct.new(:messages) do
    def send_message(**kwargs)
      messages << kwargs
      { 'message_id' => messages.length }
    end
  end

  ClientRecorder = Struct.new(:api)
  Chat = Struct.new(:id)

  let(:telegram_api) { FakeTelegramApi.new([]) }
  let(:messages) { MessagesApi.new([]) }
  let(:client) { ClientRecorder.new(messages) }
  let(:bot) do
    TelegramChessPuzzleBot::Bot.new(
      token: 'test-token',
      lichess_client: double('lichess_client'),
      fen_builder: double('fen_builder'),
      board_renderer: double('board_renderer'),
      answer_checker: TelegramChessPuzzleBot::AnswerChecker.new,
      session_store: TelegramChessPuzzleBot::PuzzleSessionStore.new,
      telegram_api: telegram_api
    )
  end

  it 'sends a self-contained board widget to a private chat' do
    bot.send(:send_test_widget, client, 42)

    method, payload = telegram_api.calls.last
    expect(method).to eq('sendWidget')
    expect(payload[:chat_id]).to eq(42)
    expect(payload[:caption]).to include('tap a piece')
    expect(payload[:html]).to include('<svg')
    expect(payload[:html]).to include('grid-template-columns:repeat(8,1fr)')
    expect(payload[:html]).not_to include('http://')
    expect(payload[:html]).not_to include('https://')
    expect(payload[:html].bytesize).to be <= 32_768
    expect(Zlib::Deflate.deflate(payload[:html], 9).bytesize).to be <= 4096
  end

  it 'does not send a widget to a group chat' do
    bot.send(:send_test_widget, client, -100_123)

    expect(telegram_api.calls).to be_empty
    expect(messages.messages.last[:text]).to include('private chat')
  end
end
