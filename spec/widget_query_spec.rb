# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'tmpdir'

RSpec.describe 'widget_query handling' do
  WidgetApi = Struct.new(:calls) do
    def call(method, payload)
      calls << [method, payload]
      method == 'sendWidget' ? { 'message_id' => 1 } : true
    end

    def send_message(**kwargs)
      calls << ['sendMessage', kwargs]
      true
    end
  end

  WidgetClient = Struct.new(:api)

  let(:api) { WidgetApi.new([]) }
  let(:client) { WidgetClient.new(api) }
  let(:store) { TelegramChessPuzzleBot::WidgetSolveStore.new(path: File.join(@dir, 'solves.json')) }
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
      telegram_api: api,
      widget_solve_store: store,
      widget_message_store: TelegramChessPuzzleBot::WidgetMessageStore.new(path: File.join(@dir, 'messages.json'))
    )
  end

  before do
    @dir = Dir.mktmpdir
    allow(lichess_client).to receive(:fetch_daily_puzzle).and_return(
      'game' => { 'pgn' => '1. e4 e5' },
      'puzzle' => { 'id' => 'f3CVY', 'rating' => 1933, 'initialPly' => 27, 'solution' => %w[d8b6 g1h1 g6h5] }
    )
    allow(fen_builder).to receive(:build)
      .and_return('r2qnrk1/p2bBp1p/2p1p1p1/3pP2Q/5P2/2NB4/PPP3PP/R4RK1 b - - 0 14')
    bot.send(:send_test_widget, client, 42)
    api.calls.clear
  end

  after { FileUtils.remove_entry(@dir) }

  def query(data, message_id: 1, chat_id: 42, user_id: 7)
    { 'id' => 'q-1', 'message_id' => message_id, 'chat' => { 'id' => chat_id },
      'from' => { 'id' => user_id }, 'data' => data }
  end

  it 'answers before replying and records the solve' do
    bot.send(:handle_widget_query, client, query(JSON.generate(t: 'solved', p: 'f3CVY', ms: 12_345)))

    methods = api.calls.map(&:first)
    expect(methods).to eq(%w[answerWidgetQuery sendMessage])

    answer = api.calls.first.last
    expect(answer[:widget_query_id]).to eq('q-1')
    expect(JSON.parse(answer[:data])).to include('ok' => true, 'n' => 1)

    reply = api.calls.last.last
    expect(reply[:chat_id]).to eq(42)
    expect(reply[:text]).to include('#f3CVY')
    expect(reply[:text]).to include('12.3')
    expect(reply[:text]).to include('всего 1')
  end

  it 'counts a puzzle only once' do
    bot.send(:handle_widget_query, client, query(JSON.generate(t: 'solved', p: 'f3CVY', ms: 5_000)))
    bot.send(:handle_widget_query, client, query(JSON.generate(t: 'solved', p: 'f3CVY', ms: 6_000)))

    answers = api.calls.select { |m, _| m == 'answerWidgetQuery' }.map { |_, p| JSON.parse(p[:data]) }
    expect(answers.map { |a| a['n'] }).to eq([1, 1])
    expect(api.calls.count { |m, _| m == 'sendMessage' }).to eq(1)
  end

  it 'rejects a solve for a puzzle it never sent' do
    bot.send(:handle_widget_query, client, query(JSON.generate(t: 'solved', p: 'zzzzz', ms: 1_000)))

    expect(api.calls.map(&:first)).to eq(['answerWidgetQuery'])
    expect(JSON.parse(api.calls.last.last[:data])['ok']).to be false
  end

  it 'rejects malformed data without raising' do
    bot.send(:handle_widget_query, client, query('not json'))

    expect(api.calls.map(&:first)).to eq(['answerWidgetQuery'])
    expect(JSON.parse(api.calls.last.last[:data])['ok']).to be false
  end
end
