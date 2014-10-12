require 'rubygems'
require 'bundler/setup'
require 'rspec'
require 'pry'
require 'convergence'
Dir["#{File.dirname(__FILE__)}/integrations/**/*.rb"].each { |f| require f }

$default_output = File.open('/dev/null', 'w')

def mysql_settings
  mysql_settings = YAML.load_file("#{File.dirname(__FILE__)}/config/spec_database.yml")['mysql']
  Convergence::Config.new(Hash[mysql_settings.map { |k, v| [k.to_sym, v] }])
end

RSpec.configure do |config|
  config.filter_run :focus
  config.run_all_when_everything_filtered = true
end
