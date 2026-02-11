# frozen_string_literal: true

require 'telegram_chess_puzzle_bot'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
