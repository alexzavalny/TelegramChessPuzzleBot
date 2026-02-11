# frozen_string_literal: true

module TelegramChessPuzzleBot
  class BoardRenderer
    LIGHT = ChunkyPNG::Color.from_hex('#F0D9B5')
    DARK = ChunkyPNG::Color.from_hex('#B58863')
    CELL = 72
    PADDING = 20
    PIECE_SIZE = 58

    PIECE_FILES = {
      'K' => 'white.king.png',
      'Q' => 'white.queen.png',
      'R' => 'white.rook.png',
      'B' => 'white.bishop.png',
      'N' => 'white.knight.png',
      'P' => 'white.pawn.png',
      'k' => 'black.king.png',
      'q' => 'black.queen.png',
      'r' => 'black.rook.png',
      'b' => 'black.bishop.png',
      'n' => 'black.knight.png',
      'p' => 'black.pawn.png'
    }.freeze

    def initialize(piece_dir: File.expand_path('../../img', __dir__))
      @piece_dir = piece_dir
      @piece_cache = {}
    end

    def render_png(fen:, puzzle_id:, output_dir: Dir.tmpdir)
      placement = fen.split.first
      squares = parse_placement(placement)
      size = (CELL * 8) + (PADDING * 2)

      image = ChunkyPNG::Image.new(size, size, ChunkyPNG::Color::WHITE)
      draw_board(image)
      draw_pieces(image, squares)

      path = File.join(output_dir, "puzzle_#{puzzle_id}.png")
      image.save(path)
      path
    end

    private

    def parse_placement(placement)
      squares = {}
      rows = placement.split('/')

      rows.each_with_index do |row, row_idx|
        file_idx = 0
        rank = 8 - row_idx

        row.each_char do |char|
          if char.match?(/\d/)
            file_idx += char.to_i
          else
            file = ('a'.ord + file_idx).chr
            squares["#{file}#{rank}"] = char
            file_idx += 1
          end
        end
      end

      squares
    end

    def draw_board(image)
      8.times do |rank_idx|
        8.times do |file_idx|
          x0 = PADDING + (file_idx * CELL)
          y0 = PADDING + (rank_idx * CELL)
          color = (file_idx + rank_idx).even? ? LIGHT : DARK
          fill_rect(image, x0, y0, CELL, CELL, color)
        end
      end
    end

    def draw_pieces(image, squares)
      squares.each do |square, piece|
        sprite = load_piece(piece)
        next unless sprite

        file = square[0]
        rank = square[1].to_i
        x0 = PADDING + ((file.ord - 'a'.ord) * CELL)
        y0 = PADDING + ((8 - rank) * CELL)

        sx = x0 + ((CELL - sprite.width) / 2)
        sy = y0 + ((CELL - sprite.height) / 2)
        image.compose!(sprite, sx, sy)
      end
    end

    def load_piece(piece_code)
      @piece_cache[piece_code] ||= begin
        filename = PIECE_FILES[piece_code]
        return nil unless filename

        path = File.join(@piece_dir, filename)
        return nil unless File.exist?(path)

        source = ChunkyPNG::Image.from_file(path)
        resize_nearest(source, PIECE_SIZE, PIECE_SIZE)
      end
    end

    def resize_nearest(source, target_w, target_h)
      return source if source.width == target_w && source.height == target_h

      scaled = ChunkyPNG::Image.new(target_w, target_h, ChunkyPNG::Color::TRANSPARENT)
      x_ratio = source.width.to_f / target_w
      y_ratio = source.height.to_f / target_h

      target_h.times do |y|
        src_y = [(y * y_ratio).floor, source.height - 1].min
        target_w.times do |x|
          src_x = [(x * x_ratio).floor, source.width - 1].min
          scaled[x, y] = source[src_x, src_y]
        end
      end

      scaled
    end

    def fill_rect(image, x, y, w, h, color)
      x_end = [x + w - 1, image.width - 1].min
      y_end = [y + h - 1, image.height - 1].min
      x_start = [x, 0].max
      y_start = [y, 0].max

      (y_start..y_end).each do |yy|
        (x_start..x_end).each do |xx|
          image[xx, yy] = color
        end
      end
    end
  end
end
