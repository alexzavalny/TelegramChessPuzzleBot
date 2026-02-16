# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TelegramChessPuzzleBot::Bot do
  ApiRecorder = Struct.new(:messages) do
    def send_message(**kwargs)
      messages << kwargs
    end
  end

  ClientRecorder = Struct.new(:api)
  Chat = Struct.new(:id)
  User = Struct.new(:id, :username, :first_name)
  Message = Struct.new(:chat, :text, :from)

  subject(:bot) do
    described_class.new(
      token: 'test-token',
      lichess_client: double('lichess_client'),
      fen_builder: double('fen_builder'),
      board_renderer: double('board_renderer'),
      answer_checker: TelegramChessPuzzleBot::AnswerChecker.new,
      session_store: session_store
    )
  end

  let(:session_store) { TelegramChessPuzzleBot::PuzzleSessionStore.new }
  let(:api) { ApiRecorder.new([]) }
  let(:client) { ClientRecorder.new(api) }
  let(:chat_id) { 42 }
  let(:user_id) { 1001 }
  let(:message_user) { User.new(user_id, 'alice', 'Alice') }
  let(:chat) { Chat.new(chat_id) }

  before do
    puzzle = TelegramChessPuzzleBot::DailyPuzzle.new(
      id: 'p1',
      rating: 1500,
      themes: [],
      solution: %w[a2a4 a7a5 b2b4 b7b5],
      initial_ply: 0,
      game_id: 'g1',
      pgn: '',
      fen: '',
      side_to_move: 'w'
    )
    session_store.put(chat_id, puzzle)
  end

  it 'accepts multiple user moves in one message and completes the line' do
    message = Message.new(chat, 'a2a4 b2b4', message_user)

    bot.send(:check_answer, client, message)

    sent = api.messages.last
    expect(sent[:parse_mode]).to eq('HTML')
    expect(sent[:text]).to include('Accepted 2 moves.')
    expect(sent[:text]).to include('Opponent replies:')
    expect(sent[:text]).to include('a7a5 b7b5')
    expect(sent[:text]).to include('Line complete. You solved it.')

    session = session_store.get(chat_id)
    expect(session.progress_by_user[user_id]).to eq(0)
    expect(session.scores[user_id]['correct_moves']).to eq(2)
    expect(session.scores[user_id]['solved_count']).to eq(1)
  end

  it 'applies correct prefix and stops at first wrong move in the same message' do
    message = Message.new(chat, 'a2a4 h2h4', message_user)

    bot.send(:check_answer, client, message)

    sent = api.messages.last
    expect(sent[:parse_mode]).to eq('HTML')
    expect(sent[:text]).to include('Accepted 1 move.')
    expect(sent[:text]).to include('Opponent replies:')
    expect(sent[:text]).to include('a7a5')
    expect(sent[:text]).to include('Then wrong move: h2h4')

    session = session_store.get(chat_id)
    expect(session.progress_by_user[user_id]).to eq(2)
    expect(session.scores[user_id]['correct_moves']).to eq(1)
    expect(session.scores[user_id]['solved_count']).to eq(0)
  end
end
