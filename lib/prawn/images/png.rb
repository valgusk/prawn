# encoding: ASCII-8BIT

# frozen_string_literal: true

# png.rb : Extracts the data from a PNG that is needed for embedding
#
# Based on some similar code in PDF::Writer by Austin Ziegler
#
# Copyright April 2008, James Healy.  All Rights Reserved.
#
# This is free software. Please see the LICENSE and COPYING files for details.

require 'stringio'
require 'pathname'

module Prawn
  module Images
    # A convenience class that wraps the logic for extracting the parts
    # of a PNG image that we need to embed them in a PDF
    #
    class PNG < Image
      # @group Extension API

      attr_reader :palette, :img_data, :transparency
      attr_reader :width, :height, :bits
      attr_reader :color_type, :compression_method, :filter_method
      attr_reader :interlace_method, :alpha_channel
      attr_accessor :scaled_width, :scaled_height

      def self.can_render?(image_blob)
        spec =
          if image_blob.is_a?(Pathname)
            File.read(image_blob, 8, binmode: true)
          else
            image_blob[0, 8]
          end

        spec.unpack('C*') == [137, 80, 78, 71, 13, 10, 26, 10]
      end

      # Process a new PNG image
      #
      # <tt>data</tt>:: A binary string of PNG data
      #
      def initialize(data)
        super()

        if data.is_a?(Pathname)
          tempfile = Tempfile.new

          loader_results =
            Prawn::Bin.exec(:load_png_data, path: data, result_path: tempfile.path)

          @img_data = FileBackedStreamData.new(Pathname.new(tempfile.path), file: tempfile)
        else
          loader_results = Prawn::Images::PNGHelpers::DataLoader.
            new(data: data.dup).
            call

          @img_data = loader_results[:img_data]
        end

        @palette = loader_results[:palette]
        @transparency = loader_results[:transparency]
        @width = loader_results[:width]
        @height = loader_results[:height]
        @bits = loader_results[:bits]
        @color_type = loader_results[:color_type]
        @compression_method = loader_results[:compression_method]
        @filter_method = loader_results[:filter_method]
        @interlace_method = loader_results[:interlace_method]
      end

      # number of color components to each pixel
      #
      def colors
        case color_type
        when 0, 3, 4
          1
        when 2, 6
          3
        end
      end

      # split the alpha channel data from the raw image data in images
      # where it's required.
      #
      def split_alpha_channel!
        if alpha_channel?
          if color_type == 3
            generate_alpha_channel
          else
            split_image_data
          end
        end
      end

      def alpha_channel?
        return true if color_type == 4 || color_type == 6
        return @transparency.any? if color_type == 3

        false
      end

      # Build a PDF object representing this image in +document+, and return
      # a Reference to it.
      #
      def build_pdf_object(document)
        if compression_method != 0
          raise Errors::UnsupportedImageType,
            'PNG uses an unsupported compression method'
        end

        if filter_method != 0
          raise Errors::UnsupportedImageType,
            'PNG uses an unsupported filter method'
        end

        if interlace_method != 0
          raise Errors::UnsupportedImageType,
            'PNG uses unsupported interlace method'
        end

        # some PNG types store the colour and alpha channel data together,
        # which the PDF spec doesn't like, so split it out.
        split_alpha_channel!

        case colors
        when 1
          color = :DeviceGray
        when 3
          color = :DeviceRGB
        else
          raise Errors::UnsupportedImageType,
            "PNG uses an unsupported number of colors (#{png.colors})"
        end

        # build the image dict
        obj = document.ref!(
          Type: :XObject,
          Subtype: :Image,
          Height: height,
          Width: width,
          BitsPerComponent: bits
        )

        # append the actual image data to the object as a stream
        obj << img_data

        obj.stream.filters << {
          FlateDecode: {
            Predictor: 15,
            Colors: colors,
            BitsPerComponent: bits,
            Columns: width
          }
        }

        # sort out the colours of the image
        if palette.empty?
          obj.data[:ColorSpace] = color
        else
          # embed the colour palette in the PDF as a object stream
          palette_obj = document.ref!({})
          palette_obj << palette

          # build the color space array for the image
          obj.data[:ColorSpace] = [
            :Indexed,
            :DeviceRGB,
            (palette.size / 3) - 1,
            palette_obj
          ]
        end

        # *************************************
        # add transparency data if necessary
        # *************************************

        # For PNG color types 0, 2 and 3, the transparency data is stored in
        # a dedicated PNG chunk, and is exposed via the transparency attribute
        # of the PNG class.
        if transparency[:grayscale]
          # Use Color Key Masking (spec section 4.8.5)
          # - An array with N elements, where N is two times the number of color
          #   components.
          val = transparency[:grayscale]
          obj.data[:Mask] = [val, val]
        elsif transparency[:rgb]
          # Use Color Key Masking (spec section 4.8.5)
          # - An array with N elements, where N is two times the number of color
          #   components.
          rgb = transparency[:rgb]
          obj.data[:Mask] = rgb.map { |x| [x, x] }.flatten
        end

        # For PNG color types 4 and 6, the transparency data is stored as
        # a alpha channel mixed in with the main image data. The PNG class
        # separates it out for us and makes it available via the alpha_channel
        # attribute
        if alpha_channel?
          smask_obj = document.ref!(
            Type: :XObject,
            Subtype: :Image,
            Height: height,
            Width: width,
            BitsPerComponent: bits,
            ColorSpace: :DeviceGray,
            Decode: [0, 1]
          )
          smask_obj.stream << alpha_channel

          smask_obj.stream.filters << {
            FlateDecode: {
              Predictor: 15,
              Colors: 1,
              BitsPerComponent: bits,
              Columns: width
            }
          }
          obj.data[:SMask] = smask_obj
        end

        obj
      end

      # Returns the minimum PDF version required to support this image.
      def min_pdf_version
        if bits > 8
          # 16-bit color only supported in 1.5+ (ISO 32000-1:2008 8.9.5.1)
          1.5
        elsif alpha_channel?
          # Need transparency for SMask
          1.4
        else
          1.0
        end
      end

      private

      def split_image_data
        raise 'nope' if @img_data.is_a?(FileBackedStreamData)

        alpha_bytes = bits / 8
        color_bytes = colors * bits / 8

        scanline_length = (color_bytes + alpha_bytes) * width + 1
        scanlines = @img_data.bytesize / scanline_length
        pixels = width * height

        data = StringIO.new(@img_data)
        data.binmode

        color_data = [0x00].pack('C') * (pixels * color_bytes + scanlines)
        color = StringIO.new(color_data)
        color.binmode

        @alpha_channel = [0x00].pack('C') * (pixels * alpha_bytes + scanlines)
        alpha = StringIO.new(@alpha_channel)
        alpha.binmode

        scanlines.times do |line|
          data.seek(line * scanline_length)

          filter = data.getbyte

          color.putc filter
          alpha.putc filter

          width.times do
            color.write data.read(color_bytes)
            alpha.write data.read(alpha_bytes)
          end
        end

        @img_data = color_data
      end

      def generate_alpha_channel
        raise 'nope' if @img_data.is_a?(FileBackedStreamData)

        alpha_palette = Hash.new(0xff)
        0.upto(palette.bytesize / 3) do |n|
          alpha_palette[n] = @transparency[:palette][n] || 0xff
        end

        scanline_length = width + 1
        scanlines = @img_data.bytesize / scanline_length
        pixels = width * height

        data = StringIO.new(@img_data)
        data.binmode

        @alpha_channel = [0x00].pack('C') * (pixels + scanlines)
        alpha = StringIO.new(@alpha_channel)
        alpha.binmode

        scanlines.times do |line|
          data.seek(line * scanline_length)

          filter = data.getbyte

          alpha.putc filter

          width.times do
            color = data.read(1).unpack1('C')
            alpha.putc alpha_palette[color]
          end
        end
      end
    end
  end
end
