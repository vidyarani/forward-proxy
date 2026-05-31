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

desc 'Run setup (install deps, create state/cert dirs)'
task :setup do
  sh 'bin/setup'
end

task default: :spec

desc 'Start the forward proxy server in foreground'
task :server do
  ruby 'bin/forward-proxy', 'run'
end

desc 'Start the forward proxy as a daemon'
task :start do
  ruby 'bin/forward-proxy', 'start'
end

desc 'Stop the forward proxy daemon'
task :stop do
  ruby 'bin/forward-proxy', 'stop'
end

desc 'Check forward proxy daemon status'
task :status do
  ruby 'bin/forward-proxy', 'status'
end

desc 'Restart the forward proxy daemon'
task :restart do
  ruby 'bin/forward-proxy', 'restart'
end

desc 'Open an IRB console with the library loaded'
task :console do
  require 'irb'
  lib_dir = File.expand_path('lib', __dir__)
  Dir["#{lib_dir}/*.rb"].each { |f| require f }
  IRB.start
end

desc 'Run RuboCop'
task :lint do
  require 'rubocop'
  cli = RuboCop::CLI.new
  cli.run
rescue LoadError
  puts 'RuboCop not installed. Run `gem install rubocop rubocop-rspec` or add to Gemfile.'
end
