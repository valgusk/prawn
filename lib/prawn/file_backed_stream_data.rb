# frozen_string_literal: true

require 'pathname'

module Prawn
  class FileBackedStreamData
    attr_reader :pathname

    def initialize(pathname, file: nil)
      @file = file
      @pathname = pathname
    end

    def pdf_flate_encode(params)
      encoded_tempfile = Tempfile.new

      result = ::Prawn::Bin.exec(
        :zlib_process_file,
        path: @pathname,
        result_path: encoded_tempfile.path,
        action: :deflate,
        params: params
      )

      return unless result

      self.class.new(encoded_tempfile.path, file: encoded_tempfile)
    end

    def pdf_flate_decode(params)
      encoded_tempfile = Tempfile.new

      result = ::Prawn::Bin.exec(
        :zlib_process_file,
        path: @pathname,
        result_path: encoded_tempfile.path,
        action: :inflate,
        params: params
      )

      return unless result

      self.class.new(encoded_tempfile.path, file: encoded_tempfile)
    end
  end
end