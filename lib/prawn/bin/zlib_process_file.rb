require_relative '../bin'
require 'zlib'

# Prawn::Bin.exec(:zlib_process_file, path: 'test.jpg', result_path: 'deflatedtest.jpg', action: :deflate, params: params)

def main(path:, result_path:, action:, params:)
  if action == :deflate
    File.binwrite(result_path, Zlib::Deflate.deflate(File.binread(path)))
  elsif action == :inflate
    File.binwrite(result_path, Zlib::Deflate.inflate(File.binread(path)))
  else
    return false
  end

  true
end

Prawn::Bin.print_return_value(main(**Prawn::Bin.args_to_kwargs(ARGV)))

