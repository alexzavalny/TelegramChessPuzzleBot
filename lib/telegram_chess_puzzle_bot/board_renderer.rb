# frozen_string_literal: true

module TelegramChessPuzzleBot
  class BoardRenderer
    LIGHT = ChunkyPNG::Color.from_hex('#F0D9B5')
    DARK = ChunkyPNG::Color.from_hex('#B58863')
    WHITE_PIECE = ChunkyPNG::Color.from_hex('#FFFFFF')
    BLACK_PIECE = ChunkyPNG::Color.from_hex('#1F1F1F')
    GLYPH_DARK = ChunkyPNG::Color.from_hex('#2D2D2D')
    GLYPH_LIGHT = ChunkyPNG::Color.from_hex('#EDEDED')

    CELL = 72
    PADDING = 20

    FONT = {
      'K' => %w[11111 00100 01010 10001 11111 10001 10001],
      'Q' => %w[01110 10001 10001 10001 10101 10010 01101],
      'R' => %w[11110 10001 10001 11110 10100 10010 10001],
      'B' => %w[11110 10001 11110 10001 10001 10001 11110],
      'N' => %w[10001 11001 10101 10011 10001 10001 10001],
      'P' => %w[11110 10001 10001 11110 10000 10000 10000]
    }.freeze

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
        file = square[0]
        rank = square[1].to_i
        x0 = PADDING + ((file.ord - 'a'.ord) * CELL)
        y0 = PADDING + ((8 - rank) * CELL)

        center_x = x0 + (CELL / 2)
        center_y = y0 + (CELL / 2)

        white = piece == piece.upcase
        draw_disc(image, center_x, center_y, 22, white ? WHITE_PIECE : BLACK_PIECE)
        draw_glyph(image, piece.upcase, center_x - 12, center_y - 16, white ? GLYPH_DARK : GLYPH_LIGHT)
      end
    end

    def draw_disc(image, cx, cy, radius, color)
      (cy - radius..cy + radius).each do |y|
        (cx - radius..cx + radius).each do |x|
          next unless x.between?(0, image.width - 1) && y.between?(0, image.height - 1)

          dx = x - cx
          dy = y - cy
          image[x, y] = color if (dx * dx) + (dy * dy) <= radius * radius
        end
      end
    end

    def draw_glyph(image, glyph, x0, y0, color)
      bitmap = FONT[glyph]
      return unless bitmap

      scale = 4
      bitmap.each_with_index do |row, y|
        row.each_char.with_index do |bit, x|
          next unless bit == '1'

          fill_rect(image, x0 + (x * scale), y0 + (y * scale), scale, scale, color)
        end
      end
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
