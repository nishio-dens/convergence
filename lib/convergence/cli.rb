# frozen_string_literal: true

require 'thor'
require 'convergence/version'
require 'convergence/config'
require 'convergence/command/apply'
require 'convergence/command/diff'
require 'convergence/command/dryrun'
require 'convergence/command/export'

class Convergence::CLI < Thor
  default_command :__fallback # TODO: `__fallback` will be removed in a future version(maybe v0.4.0)
 
  map %w[--version -v] => :version

  desc 'apply FILE', 'execute sql to your database'
  method_option :config, aliases: '-c', type: :string, required: true, desc: 'Database Yaml Setting'
  def apply(file)
    opts = { input: file }
    Convergence::Command::Apply.new(opts, config: config).execute
  end

  desc 'diff FILE1 FILE2', 'print diff of DSLs'
  def diff(file1, file2)
    opts = { diff: [file1, file2] }
    Convergence::Command::Diff.new(opts, config: config).execute
  end

  desc 'dryrun FILE', 'dryrun for apply'
  method_option :config, aliases: '-c', type: :string, required: true, desc: 'Database Yaml Setting'
  def dryrun(file)
    opts = { input: file }
    Convergence::Command::Dryrun.new(opts, config: config).execute
  end

  desc 'export', 'export db schema to dsl'
  method_option :config, aliases: '-c', type: :string, required: true, desc: 'Database Yaml Setting'
  def export
    opts = {}
    Convergence::Command::Export.new(opts, config: config).execute
  end

  desc 'version', 'print the version'
  def version
    puts "version #{Convergence::VERSION}"
  end

  # TODO: `__fallback` will be removed in a future version(maybe v0.4.0)
  desc '', '', hide: true
  method_option :config,
                aliases: '-c', type: :string,
                desc: 'Database Yaml Setting'
  method_option :diff,
                aliases: '-d', type: :array, default: nil,
                banner: 'DSL1 DSL2'
  method_option :export,
                aliases: '-e', type: :boolean, default: false,
                desc: 'export db schema to dsl'
  method_option :input,
                aliases: '-i', type: :string,
                desc: 'Input DSL'
  method_option :dryrun,
                type: :boolean, default: false
  method_option :apply,
                type: :boolean, default: false,
                desc: 'execute sql to your database'
  def __fallback
    command_klass =
      if !options[:diff].nil? && !options[:diff].empty?
        opts = { diff: options[:diff] }
        Convergence::Command::Diff
      elsif options[:export]
        opts = {}
        Convergence::Command::Export
      elsif options[:dryrun]
        opts = { input: options[:input] }
        Convergence::Command::Dryrun
      elsif options[:apply]
        opts = { input: options[:input] }
        Convergence::Command::Apply
      end

    if command_klass
      deprecation_warning
      command_klass.new(opts, config: config).execute
    else
      help
    end
  end

  private

  def config
    return unless options[:config]
    @config ||= Convergence::Config.load(options[:config])
  end

  def deprecation_warning
    warn '[DEPRECATION] Option style is deprecated. Please use subscommand style.'
  end
end
