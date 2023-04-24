require 'open3'
require 'pathname'

module Prawn
  module Bin
    def self.exec(script_name, **kwargs)
      path = Pathname.new(__dir__).join('bin', "#{script_name}.rb")
      args = kwargs.flat_map { |key, val| ["--#{key}", Marshal.dump(val)] }

      puts "#{RbConfig.ruby} #{path.to_s} #{args.map(&:inspect).join(' ')}"

      result, err, status = Bundler.with_unbundled_env do
        Open3.capture3(RbConfig.ruby, path.to_s, *args, binmode: true)
      end

      raise "#{script_name} failed for #{kwargs} with #{err}!" if status != 0

      Marshal.load(result)
    end

    def self.args_to_kwargs(argv)
      argv.each_slice(2).to_h do |(param_name, param_value)|
        [param_name.delete_prefix('--').to_sym, Marshal.load(param_value)]
      end
    end

    def self.print_return_value(return_value)
      puts Marshal.dump(return_value)
    end
  end
end