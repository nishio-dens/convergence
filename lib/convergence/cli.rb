# frozen_string_literal: true

require 'thor'
require 'convergence/module'
require 'convergence/config'

class Convergence::CLI < Thor
  map %w[--version -v] => :version

  desc 'apply FILE', 'execute sql to your database'
  method_option :config, aliases: '-c', type: :string, required: true, desc: 'Database Yaml Setting'
  method_option :dry_run, type: :boolean
  method_option :rollback_dry_run, type: :boolean
  method_option :ignore_auto_increment, type: :boolean, desc: 'Do not generate AUTO_INCREMENT change queries'
  method_option :safe_migration, type: :boolean, desc: 'Do not generate DROP TABLE queries'

  def self.exit_on_failure?
    true
  end

  def apply(file)
    opts = {
      input: file,
      ignore_auto_increment: options[:ignore_auto_increment],
      safe_migration: options[:safe_migration]
    }
    if options[:dry_run]
      require 'convergence/command/dryrun'
      Convergence::Command::Dryrun.new(opts, config: config).execute
    elsif options[:rollback_dry_run]
      require 'convergence/command/rollback_dryrun'
      Convergence::Command::RollbackDryrun.new(opts, config: config).execute
    else
      require 'convergence/command/apply'
      Convergence::Command::Apply.new(opts, config: config).execute
    end
  end

  desc 'diff FILE1 FILE2', 'print diff of DSLs'
  def diff(file1, file2)
    require 'convergence/command/diff'
    opts = { diff: [file1, file2] }
    Convergence::Command::Diff.new(opts, config: config).execute
  end

  desc 'export', 'export db schema to dsl'
  method_option :config, aliases: '-c', type: :string, required: true, desc: 'Database Yaml Setting'
  method_option :dump_rails_migration, type: :boolean, desc: 'Output an ActiveRecord migration file instead of a Convergence DSL file'
  method_option :filename, type: :string, desc: 'Base filename (without timestamp/extension) used for --dump-rails-migration'
  def export
    require 'convergence/command/export'
    opts = { dump_rails_migration: options[:dump_rails_migration], filename: options[:filename] }
    Convergence::Command::Export.new(opts, config: config).execute
  end

  desc 'version', 'print the version'
  def version
    require 'convergence/version'
    puts "version #{Convergence::VERSION}"
  end

  private

  def config
    return unless options[:config]
    @config ||= Convergence::Config.load(options[:config])
  end
end
