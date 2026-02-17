# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TelegramChessPuzzleBot::Bot do
  ApiRecorder = Struct.new(:messages, :deleted_messages, :reactions, :next_message_id) do
    def send_message(**kwargs)
      self.next_message_id ||= 1
      messages << kwargs
      result = { 'message_id' => next_message_id }
      self.next_message_id += 1
      result
    end

    def delete_message(**kwargs)
      deleted_messages << kwargs
    end

    def set_message_reaction(**kwargs)
      reactions << kwargs
    end
  end

  ClientRecorder = Struct.new(:api)
  Chat = Struct.new(:id)
  User = Struct.new(:id, :username, :first_name)
  Message = Struct.new(:chat, :text, :from, :message_id)

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
  let(:api) { ApiRecorder.new([], [], [], 1) }
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
    message = Message.new(chat, 'a2a4 b2b4', message_user, 11)

    bot.send(:check_answer, client, message)

    sent = api.messages.last
    expect(sent[:parse_mode]).to eq('HTML')
    expect(sent[:reply_to_message_id]).to eq(11)
    expect(sent[:text]).to include('Accepted 2 moves.')
    expect(sent[:text]).to include('Opponent replies:')
    expect(sent[:text]).to include('a7a5 b7b5')
    expect(sent[:text]).to include('Line complete. You solved it.')
    expect(sent[:text]).to include('Solved by: ⭐@alice')

    session = session_store.get(chat_id)
    expect(session.progress_by_user[user_id]).to eq(0)
    expect(session.scores[user_id]['solved_count']).to eq(1)
    expect(session.scores[user_id]['flawless_solved_count']).to eq(1)
    expect(sent[:text]).not_to include('Scoreboard:')
    expect(api.deleted_messages).to be_empty
    expect(api.reactions).to eq([{
                                  chat_id: chat_id,
                                  message_id: 11,
                                  reaction: [{ type: 'emoji', emoji: '👍' }]
                                }])
  end

  it 'routes help command to help output even when a puzzle is pending' do
    message = Message.new(chat, 'help', message_user, 10)

    bot.send(:handle_message, client, message)

    sent = api.messages.last
    expect(sent[:chat_id]).to eq(chat_id)
    expect(sent[:text]).to include('Commands:')
    expect(sent[:text]).to include('- help: show help')
    expect(sent[:text]).to include('- daily: get today\'s Lichess daily puzzle')
    expect(api.reactions).to be_empty
  end

  it 'applies correct prefix and stops at first wrong move in the same message' do
    message = Message.new(chat, 'a2a4 h2h4', message_user, 12)

    bot.send(:check_answer, client, message)

    sent = api.messages.last
    expect(sent[:parse_mode]).to eq('HTML')
    expect(sent[:reply_to_message_id]).to eq(12)
    expect(sent[:text]).to include('Accepted 1 move.')
    expect(sent[:text]).to include('Opponent replies:')
    expect(sent[:text]).to include('a7a5')
    expect(sent[:text]).to include('Your turn from the current position.')
    expect(sent[:text]).not_to include('wrong move')

    session = session_store.get(chat_id)
    expect(session.progress_by_user[user_id]).to eq(2)
    expect(session.scores[user_id]).to be_nil
    expect(api.deleted_messages).to be_empty
    expect(api.reactions).to eq([{
                                  chat_id: chat_id,
                                  message_id: 12,
                                  reaction: [{ type: 'emoji', emoji: '👎' }]
                                }])
  end

  it 'uses reaction only for a fully wrong guess and sends no message' do
    message = Message.new(chat, 'h2h4', message_user, 13)

    bot.send(:check_answer, client, message)

    expect(api.messages).to be_empty
    expect(api.reactions).to eq([{
                                  chat_id: chat_id,
                                  message_id: 13,
                                  reaction: [{ type: 'emoji', emoji: '👎' }]
                                }])
  end

  it 'deletes older bot replies to the user when the line is solved' do
    first = Message.new(chat, 'a2a4', message_user, 20)
    second = Message.new(chat, 'b2b4', message_user, 21)

    bot.send(:check_answer, client, first)
    bot.send(:check_answer, client, second)

    expect(api.messages.length).to eq(2)
    expect(api.messages.last[:text]).to include('Line complete. You solved it.')
    expect(api.messages.last[:text]).to include('Solved by: ⭐@alice')
    expect(api.deleted_messages).to eq([{ chat_id: chat_id, message_id: 1 }])
    expect(api.reactions).to eq([
                                  {
                                    chat_id: chat_id,
                                    message_id: 20,
                                    reaction: [{ type: 'emoji', emoji: '👍' }]
                                  },
                                  {
                                    chat_id: chat_id,
                                    message_id: 21,
                                    reaction: [{ type: 'emoji', emoji: '👍' }]
                                  }
                                ])
  end

  it 'does not add a star when the user solves after earlier mistakes' do
    wrong_then_partial = Message.new(chat, 'a2a4 h2h4', message_user, 30)
    finish = Message.new(chat, 'b2b4', message_user, 31)

    bot.send(:check_answer, client, wrong_then_partial)
    bot.send(:check_answer, client, finish)

    expect(api.messages.last[:text]).to include('Solved by: @alice')
    expect(api.messages.last[:text]).not_to include('⭐@alice')
    session = session_store.get(chat_id)
    expect(session.scores[user_id]['solved_count']).to eq(1)
    expect(session.scores[user_id]['flawless_solved_count']).to eq(0)
  end
end
