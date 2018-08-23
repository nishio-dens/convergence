require 'rubygems'
require 'bundler/setup'
require 'rspec'
require 'pry'
require 'convergence'
require 'convergence/command'
Dir["#{File.dirname(__FILE__)}/integrations/**/*.rb"].each { |f| require f }

$default_output = File.open('/dev/null', 'w')

def mysql_settings
  mysql_settings = YAML.load_file("#{File.dirname(__FILE__)}/config/spec_database.yml")['mysql']
  Convergence::Config.new(Hash[mysql_settings.map { |k, v| [k.to_sym, v] }])
end

def rollback
  # FIXME But I have no idea to rollback create/drop/alter table of mysql
  sqls = File.open("#{File.dirname(__FILE__)}/fixtures/test_db.sql")
    .read
    .split(';')
    .map(&:strip)
    .reject(&:empty?)
  sqls.each do |sql|
    Convergence::Command.new({}, config: mysql_settings)
      .connector
      .client
      .query("#{sql};")
  end
end

RSpec.configure do |config|
  config.filter_run_when_matching :focus
end
