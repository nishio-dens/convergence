require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'yaml'

RSpec::Core::RakeTask.new('spec')
task default: :spec

spec_database_settings = YAML.load_file("#{File.dirname(__FILE__)}/spec/config/spec_database.yml")
mysql_settings = Hash[spec_database_settings['mysql'].map { |k, v| [k.to_sym, v] }]
postgres_settings = Hash[spec_database_settings['postgresql'].map { |k, v| [k.to_sym, v] }]
sqlite_db_path = File.expand_path("#{File.dirname(__FILE__)}/spec/fixtures/#{spec_database_settings['sqlite3']['database']}")

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

    namespace :postgres do
      desc 'Build the PostgreSQL database for tests'
      task :build_databases do
        ENV['PGPASSWORD'] = postgres_settings[:password].to_s
        system("psql -U #{postgres_settings[:username]} -h #{postgres_settings[:host]} -p #{postgres_settings[:port]} -d postgres -c 'create database #{postgres_settings[:database]};'")
      end

      task :drop_databases do
        ENV['PGPASSWORD'] = postgres_settings[:password].to_s
        system("psql -U #{postgres_settings[:username]} -h #{postgres_settings[:host]} -p #{postgres_settings[:port]} -d postgres -c 'drop database if exists #{postgres_settings[:database]};'")
      end

      desc 'Create tables on the PostgreSQL test database'
      task :create_tables do
        ENV['PGPASSWORD'] = postgres_settings[:password].to_s
        query_path = "#{File.dirname(__FILE__)}/spec/fixtures/postgres_test_db.sql"
        system("psql -U #{postgres_settings[:username]} -h #{postgres_settings[:host]} -p #{postgres_settings[:port]} -d #{postgres_settings[:database]} -f #{query_path}")
      end

      desc 'Prepare the PostgreSQL test database'
      task prepare: [:build_databases, :create_tables]
      task overhaul: [:drop_databases, :build_databases, :create_tables]
    end

    namespace :sqlite do
      desc 'Remove the SQLite test database file'
      task :drop_databases do
        File.delete(sqlite_db_path) if File.exist?(sqlite_db_path)
      end

      desc 'Create tables on the SQLite test database'
      task :create_tables do
        query_path = "#{File.dirname(__FILE__)}/spec/fixtures/sqlite_test_db.sql"
        system("sqlite3 #{sqlite_db_path} < #{query_path}")
      end

      desc 'Prepare the SQLite test database'
      task prepare: [:drop_databases, :create_tables]
      task overhaul: [:drop_databases, :create_tables]
    end
  end
end
