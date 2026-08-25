require 'spec_helper'
require 'convergence/command/export'

describe 'Command::Export#execute' do
  def execute(extra_options = {})
    Convergence::Command::Export.new(extra_options, config: mysql_settings).execute
  end

  it 'should be output convergence DSL by default' do
    result = execute
    expect(result).to be_include('create_table :authors')
  end

  describe '--dump-rails-migration' do
    it 'should be output an ActiveRecord migration' do
      result = execute(dump_rails_migration: true, filename: 'add_initial_tables')
      expect(result).to be_include('# Filename:')
      expect(result).to be_include('_add_initial_tables.rb')
      expect(result).to be_include('class AddInitialTables < ActiveRecord::Migration[')
      expect(result).to be_include('create_table :authors do |t|')
    end

    it 'should use a default filename/class name when --filename is omitted' do
      result = execute(dump_rails_migration: true)
      expect(result).to be_include('class ConvergenceMigration < ActiveRecord::Migration[')
    end
  end
end
