#! env ruby

require 'pathname'
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'pry'
  gem 'pdf-core', git: 'https://github.com/valgusk/pdf-core.git', branch: 'jpg-from-pathname'
  gem 'prawn', git: 'https://github.com/valgusk/prawn.git', branch: 'jpg-from-pathname'
end

def test
  pdf = Prawn::Document.new(
    page_size: [2657, 1702],
    margin: 0
  )

  pdf.image(Pathname.new('test.jpg'))
  pdf.render_file('test.pdf')
end

test