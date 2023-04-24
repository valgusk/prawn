require_relative '../bin'
require_relative '../images/png_helpers/data_loader'
require 'digest'

# Prawn::Bin.exec(:load_png_data, path: 'test.jpg', result_path: tempfile.path)

def main(path:, result_path:)
  result = Prawn::Images::PNGHelpers::DataLoader.new(data: File.binread(path)).call

  File.binwrite(result_path, result.delete(:img_data))

  result
end

Prawn::Bin.print_return_value(main(**Prawn::Bin.args_to_kwargs(ARGV)))

