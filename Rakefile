require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
end

namespace :spec do
  RSpec::Core::RakeTask.new(:unit) do |t|
    t.pattern = 'spec/*_spec.rb'
    t.exclude_pattern = 'spec/curl_integration_spec.rb'
  end

  RSpec::Core::RakeTask.new(:integration) do |t|
    t.pattern = 'spec/curl_integration_spec.rb'
  end
end

task default: :spec

desc 'Start the forward proxy server'
task :server do
  ruby 'bin/forward-proxy'
end

desc 'Open an IRB console with the library loaded'
task :console do
  require 'irb'
  lib_dir = File.expand_path('lib', __dir__)
  Dir["#{lib_dir}/*.rb"].sort.each { |f| require f }
  IRB.start
end

desc 'Run RuboCop'
task :lint do
  begin
    require 'rubocop'
    cli = RuboCop::CLI.new
    cli.run
  rescue LoadError
    puts 'RuboCop not installed. Run `gem install rubocop rubocop-rspec` or add to Gemfile.'
  end
end
