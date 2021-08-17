require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'yaml'

RSpec::Core::RakeTask.new('spec')
task default: :spec

mysql_settings = YAML.load_file("#{File.dirname(__FILE__)}/spec/config/spec_database.yml")['mysql']
mysql_settings = Hash[mysql_settings.map { |k, v| [k.to_sym, v] }]

namespace :db do
  namespace :convergence do
    desc 'Build the databases for tests'
    task :build_databases do
      query = "create database #{mysql_settings[:database]};"
      system("mysql -u #{mysql_settings[:username]} -p#{mysql_settings[:password]} -h #{mysql_settings[:host]} --port #{mysql_settings[:port]} -e '#{query}'")
    end

    task :drop_databases do
      query = "drop database #{mysql_settings[:database]};"
      system("mysql -u #{mysql_settings[:username]} -p#{mysql_settings[:password]} -h #{mysql_settings[:host]} --port #{mysql_settings[:port]} -e '#{query}'")
    end

    desc 'Create tables on tests databases'
    task :create_tables do
      query_path = "#{File.dirname(__FILE__)}/spec/fixtures/test_db.sql"
      system("mysql -u #{mysql_settings[:username]} -p#{mysql_settings[:password]} -h #{mysql_settings[:host]} --port #{mysql_settings[:port]} #{mysql_settings[:database]} < #{query_path}")
    end

    desc 'Prepare the test databases'
    task prepare: [:build_databases, :create_tables]
    task overhaul: [:drop_databases, :build_databases, :create_tables]
  end
end
