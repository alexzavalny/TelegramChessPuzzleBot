# frozen_string_literal: true

require 'json'
require 'net/http'
require 'time'
require 'tmpdir'
require 'chunky_png'
require 'telegram/bot'

require_relative 'telegram_chess_puzzle_bot/daily_puzzle'
require_relative 'telegram_chess_puzzle_bot/lichess_client'
require_relative 'telegram_chess_puzzle_bot/puzzle_session_store'
require_relative 'telegram_chess_puzzle_bot/answer_checker'
require_relative 'telegram_chess_puzzle_bot/chess_position'
require_relative 'telegram_chess_puzzle_bot/fen_builder'
require_relative 'telegram_chess_puzzle_bot/board_renderer'
require_relative 'telegram_chess_puzzle_bot/bot'
