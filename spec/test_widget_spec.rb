# frozen_string_literal: true

require 'spec_helper'
require 'json'
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
  FEN = 'r2qnrk1/p2bBp1p/2p1p1p1/3pP2Q/5P2/2NB4/PPP3PP/R4RK1 b - - 0 14'

  let(:telegram_api) { FakeTelegramApi.new([]) }
  let(:messages) { MessagesApi.new([]) }
  let(:client) { ClientRecorder.new(messages) }
  let(:lichess_client) { double('lichess_client') }
  let(:fen_builder) { double('fen_builder') }
  let(:bot) do
    TelegramChessPuzzleBot::Bot.new(
      token: 'test-token',
      lichess_client: lichess_client,
      fen_builder: fen_builder,
      board_renderer: double('board_renderer'),
      answer_checker: TelegramChessPuzzleBot::AnswerChecker.new,
      session_store: TelegramChessPuzzleBot::PuzzleSessionStore.new,
      telegram_api: telegram_api
    )
  end

  before do
    allow(lichess_client).to receive(:fetch_daily_puzzle).and_return(
      'game' => { 'pgn' => '1. e4 e5' },
      'puzzle' => {
        'id' => 'f3CVY',
        'rating' => 1933,
        'initialPly' => 27,
        'solution' => %w[d8b6 g1h1 g6h5]
      }
    )
    allow(fen_builder).to receive(:build).and_return(FEN)
  end

  it 'bakes the position and solution into a self-contained board widget' do
    bot.send(:send_test_widget, client, 42)

    method, payload = telegram_api.calls.last
    expect(method).to eq('sendWidget')
    expect(payload[:chat_id]).to eq(42)
    expect(payload[:caption]).to include('#f3CVY')
    expect(payload[:caption]).to include('you play Black')

    html = payload[:html]
    expect(html).to include(JSON.generate(FEN))
    expect(html).to include('d8b6')
    expect(html).to include('g6h5')
    expect(html).not_to include('__PUZZLE_DATA__')
    expect(html).not_to include('http://')
    expect(html).not_to include('https://')
    expect(html.bytesize).to be <= 32_768
    expect(Zlib::Deflate.deflate(html, 9).bytesize).to be <= 4096
  end

  it 'does not send a widget to a group chat' do
    bot.send(:send_test_widget, client, -100_123)

    expect(telegram_api.calls).to be_empty
    expect(messages.messages.last[:text]).to include('private chat')
  end
end
