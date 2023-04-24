# encoding: ASCII-8BIT

# frozen_string_literal: true

require 'stringio'
require 'pathname'
require 'zlib'

module Prawn
  module Images
    module PNGHelpers
      class DataLoader
        def initialize(data:)
          @data = StringIO.new(data.dup)
        end

        def call
          load_data

          {
            palette: @palette,
            img_data: @img_data,
            transparency: @transparency,
            width: @width,
            height: @height,
            bits: @bits,
            color_type: @color_type,
            compression_method: @compression_method,
            filter_method: @filter_method,
            interlace_method: @interlace_method
          }
        end

        private

        def load_data
          data = @data
          data.rewind

          data.read(8) # Skip the default header

          @palette = +''
          @img_data = +''
          @transparency = {}

          loop do
            chunk_size = data.read(4).unpack1('N')
            section = data.read(4)
            case section
            when 'IHDR'
              # we can grab other interesting values from here (like width,
              # height, etc)
              values = data.read(chunk_size).unpack('NNCCCCC')

              @width = values[0]
              @height = values[1]
              @bits = values[2]
              @color_type = values[3]
              @compression_method = values[4]
              @filter_method = values[5]
              @interlace_method = values[6]
            when 'PLTE'
              @palette << data.read(chunk_size)
            when 'IDAT'
              @img_data << data.read(chunk_size)
            when 'tRNS'
              # This chunk can only occur once and it must occur after the
              # PLTE chunk and before the IDAT chunk
              @transparency = {}
              case @color_type
              when 3
                @transparency[:palette] = data.read(chunk_size).unpack('C*')
              when 0
                # Greyscale. Corresponding to entries in the PLTE chunk.
                # Grey is two bytes, range 0 .. (2 ^ bit-depth) - 1
                grayval = data.read(chunk_size).unpack1('n')
                @transparency[:grayscale] = grayval
              when 2
                # True colour with proper alpha channel.
                @transparency[:rgb] = data.read(chunk_size).unpack('nnn')
              end
            when 'IEND'
              # we've got everything we need, exit the loop
              break
            else
              # unknown (or un-important) section, skip over it
              data.seek(data.pos + chunk_size)
            end

            data.read(4) # Skip the CRC
          end

          @img_data = Zlib::Inflate.inflate(@img_data)
        end
      end
    end
  end
end