# frozen_string_literal: true

module TelegramChessPuzzleBot
  class ChessPosition
    FILES = ('a'..'h').to_a.freeze
    RANKS = ('1'..'8').to_a.freeze

    PIECE_TO_FEN = {
      ['w', 'K'] => 'K', ['w', 'Q'] => 'Q', ['w', 'R'] => 'R', ['w', 'B'] => 'B', ['w', 'N'] => 'N', ['w', 'P'] => 'P',
      ['b', 'K'] => 'k', ['b', 'Q'] => 'q', ['b', 'R'] => 'r', ['b', 'B'] => 'b', ['b', 'N'] => 'n', ['b', 'P'] => 'p'
    }.freeze

    attr_reader :side_to_move

    def initialize
      @board = {}
      seed_start_position
      @side_to_move = 'w'
      @castling_rights = 'KQkq'
      @en_passant = '-'
      @halfmove_clock = 0
      @fullmove_number = 1
    end

    def apply_san(san)
      move = normalize_san(san)
      return castle(:king_side) if move == 'O-O'
      return castle(:queen_side) if move == 'O-O-O'

      parsed = parse_san(move)
      from = resolve_from_square(parsed)
      raise "Cannot resolve SAN move: #{san}" unless from

      apply_normal_move(from, parsed)
    end

    def fen
      rows = (8).downto(1).map do |rank|
        empty = 0
        row = +''
        FILES.each do |file|
          piece = @board["#{file}#{rank}"]
          if piece
            row << empty.to_s if empty.positive?
            empty = 0
            row << PIECE_TO_FEN.fetch(piece)
          else
            empty += 1
          end
        end
        row << empty.to_s if empty.positive?
        row
      end

      [rows.join('/'), @side_to_move, (@castling_rights.empty? ? '-' : @castling_rights), @en_passant, @halfmove_clock, @fullmove_number].join(' ')
    end

    private

    def seed_start_position
      %w[a b c d e f g h].each do |file|
        @board["#{file}2"] = ['w', 'P']
        @board["#{file}7"] = ['b', 'P']
      end

      place_back_rank('w', '1')
      place_back_rank('b', '8')
    end

    def place_back_rank(color, rank)
      @board["a#{rank}"] = [color, 'R']
      @board["b#{rank}"] = [color, 'N']
      @board["c#{rank}"] = [color, 'B']
      @board["d#{rank}"] = [color, 'Q']
      @board["e#{rank}"] = [color, 'K']
      @board["f#{rank}"] = [color, 'B']
      @board["g#{rank}"] = [color, 'N']
      @board["h#{rank}"] = [color, 'R']
    end

    def normalize_san(san)
      san.strip.gsub(/[+#?!]/, '')
    end

    def parse_san(san)
      md = san.match(/\A(?<piece>[KQRBN])?(?<from_file>[a-h])?(?<from_rank>[1-8])?(?<capture>x)?(?<to>[a-h][1-8])(?<promotion>=?[QRBN])?\z/)
      raise "Unsupported SAN move: #{san}" unless md

      {
        piece: md[:piece] || 'P',
        from_file: md[:from_file],
        from_rank: md[:from_rank],
        capture: !md[:capture].nil?,
        to: md[:to],
        promotion: md[:promotion]&.delete('='),
        san: san
      }
    end

    def resolve_from_square(parsed)
      candidates = @board.filter_map do |square, piece|
        color, type = piece
        next unless color == @side_to_move && type == parsed[:piece]
        next unless parsed[:from_file].nil? || square[0] == parsed[:from_file]
        next unless parsed[:from_rank].nil? || square[1] == parsed[:from_rank]
        next unless legal_piece_move?(square, parsed[:to], parsed)

        square
      end

      candidates.first
    end

    def legal_piece_move?(from, to, parsed)
      color = @side_to_move
      piece = parsed[:piece]
      target = @board[to]

      return false if target && target[0] == color
      return false if parsed[:capture] && target.nil? && !(piece == 'P' && to == @en_passant)
      return false if !parsed[:capture] && !target.nil?

      case piece
      when 'P'
        legal_pawn_move?(from, to, parsed[:capture])
      when 'N'
        legal_knight_move?(from, to)
      when 'B'
        legal_bishop_move?(from, to)
      when 'R'
        legal_rook_move?(from, to)
      when 'Q'
        legal_queen_move?(from, to)
      when 'K'
        legal_king_move?(from, to)
      else
        false
      end
    end

    def legal_pawn_move?(from, to, capture)
      fx = file_index(from[0])
      fy = from[1].to_i
      tx = file_index(to[0])
      ty = to[1].to_i
      dir = @side_to_move == 'w' ? 1 : -1
      start_rank = @side_to_move == 'w' ? 2 : 7

      if capture
        (tx - fx).abs == 1 && (ty - fy) == dir
      elsif fx == tx && (ty - fy) == dir
        true
      elsif fx == tx && fy == start_rank && (ty - fy) == 2 * dir
        middle = "#{FILES[fx]}#{fy + dir}"
        @board[middle].nil?
      else
        false
      end
    end

    def legal_knight_move?(from, to)
      dx = (file_index(from[0]) - file_index(to[0])).abs
      dy = (from[1].to_i - to[1].to_i).abs
      (dx == 1 && dy == 2) || (dx == 2 && dy == 1)
    end

    def legal_bishop_move?(from, to)
      dx = (file_index(from[0]) - file_index(to[0])).abs
      dy = (from[1].to_i - to[1].to_i).abs
      return false unless dx == dy

      path_clear?(from, to)
    end

    def legal_rook_move?(from, to)
      same_file = from[0] == to[0]
      same_rank = from[1] == to[1]
      return false unless same_file || same_rank

      path_clear?(from, to)
    end

    def legal_queen_move?(from, to)
      legal_bishop_move?(from, to) || legal_rook_move?(from, to)
    end

    def legal_king_move?(from, to)
      dx = (file_index(from[0]) - file_index(to[0])).abs
      dy = (from[1].to_i - to[1].to_i).abs
      dx <= 1 && dy <= 1
    end

    def path_clear?(from, to)
      fx = file_index(from[0])
      fy = from[1].to_i
      tx = file_index(to[0])
      ty = to[1].to_i

      step_x = tx <=> fx
      step_y = ty <=> fy

      x = fx + step_x
      y = fy + step_y

      while x != tx || y != ty
        return false if @board["#{FILES[x]}#{y}"]

        x += step_x
        y += step_y
      end

      true
    end

    def apply_normal_move(from, parsed)
      to = parsed[:to]
      moving_piece = @board.delete(from)
      captured = false

      if parsed[:piece] == 'P' && parsed[:capture] && to == @en_passant && @board[to].nil?
        ep_rank = @side_to_move == 'w' ? to[1].to_i - 1 : to[1].to_i + 1
        @board.delete("#{to[0]}#{ep_rank}")
        captured = true
      elsif @board.key?(to)
        captured = true
      end

      update_castling_rights_for_rook_capture(to)

      final_piece = if parsed[:piece] == 'P' && parsed[:promotion]
                      [@side_to_move, parsed[:promotion]]
                    else
                      moving_piece
                    end

      @board[to] = final_piece
      update_castling_rights_for_move(from, moving_piece)

      setup_en_passant(from, to, moving_piece)
      update_halfmove(moving_piece, captured)
      switch_side
    end

    def castle(side)
      color = @side_to_move
      if color == 'w'
        king_from = 'e1'
        if side == :king_side
          king_to = 'g1'
          rook_from = 'h1'
          rook_to = 'f1'
        else
          king_to = 'c1'
          rook_from = 'a1'
          rook_to = 'd1'
        end
      else
        king_from = 'e8'
        if side == :king_side
          king_to = 'g8'
          rook_from = 'h8'
          rook_to = 'f8'
        else
          king_to = 'c8'
          rook_from = 'a8'
          rook_to = 'd8'
        end
      end

      king = @board.delete(king_from)
      rook = @board.delete(rook_from)
      @board[king_to] = king
      @board[rook_to] = rook

      @castling_rights = @castling_rights.delete(color == 'w' ? 'KQ' : 'kq')
      @en_passant = '-'
      @halfmove_clock += 1
      switch_side
    end

    def update_castling_rights_for_move(from, moving_piece)
      color, type = moving_piece

      if type == 'K'
        @castling_rights = @castling_rights.delete(color == 'w' ? 'KQ' : 'kq')
      elsif type == 'R'
        case from
        when 'a1' then @castling_rights = @castling_rights.delete('Q')
        when 'h1' then @castling_rights = @castling_rights.delete('K')
        when 'a8' then @castling_rights = @castling_rights.delete('q')
        when 'h8' then @castling_rights = @castling_rights.delete('k')
        end
      end
    end

    def update_castling_rights_for_rook_capture(to)
      case to
      when 'a1' then @castling_rights = @castling_rights.delete('Q')
      when 'h1' then @castling_rights = @castling_rights.delete('K')
      when 'a8' then @castling_rights = @castling_rights.delete('q')
      when 'h8' then @castling_rights = @castling_rights.delete('k')
      end
    end

    def setup_en_passant(from, to, moving_piece)
      _, type = moving_piece
      if type == 'P' && (from[1].to_i - to[1].to_i).abs == 2
        middle_rank = (from[1].to_i + to[1].to_i) / 2
        @en_passant = "#{from[0]}#{middle_rank}"
      else
        @en_passant = '-'
      end
    end

    def update_halfmove(moving_piece, captured)
      _, type = moving_piece
      @halfmove_clock = (captured || type == 'P') ? 0 : @halfmove_clock + 1
    end

    def switch_side
      if @side_to_move == 'w'
        @side_to_move = 'b'
      else
        @side_to_move = 'w'
        @fullmove_number += 1
      end
    end

    def file_index(file)
      FILES.index(file)
    end
  end
end
