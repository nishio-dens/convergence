require 'spec_helper'
require 'convergence/pretty_diff'
require 'convergence/table'

describe Convergence::PrettyDiff do
  describe '#output' do
    context 'when a table is added' do
      let(:from_tables) { {} }
      let(:to_tables) do
        { 'users' => Convergence::Table.new('users').tap { |t| t.int('id', primary_key: true) } }
      end

      it 'should show the added table with a + prefix on every line' do
        output = Convergence::PrettyDiff.new(from_tables, to_tables).output
        expect(output).to be_include('+ create_table :users do |t|')
        expect(output).to be_include('+   t.int :id, primary_key: true')
        expect(output).to be_include('+ end')
      end
    end

    context 'when a table is removed' do
      let(:from_tables) do
        { 'users' => Convergence::Table.new('users').tap { |t| t.int('id', primary_key: true) } }
      end
      let(:to_tables) { {} }

      it 'should show the removed table with a - prefix on every line' do
        output = Convergence::PrettyDiff.new(from_tables, to_tables).output
        expect(output).to be_include('- create_table :users do |t|')
        expect(output).to be_include('-   t.int :id, primary_key: true')
        expect(output).to be_include('- end')
      end
    end

    context 'when a table column is changed' do
      let(:from_tables) do
        { 'users' => Convergence::Table.new('users').tap { |t| t.varchar('name', limit: 100) } }
      end
      let(:to_tables) do
        { 'users' => Convergence::Table.new('users').tap { |t| t.varchar('name', limit: 200) } }
      end

      it 'should show a unified diff of only the changed column' do
        output = Convergence::PrettyDiff.new(from_tables, to_tables).output
        expect(output).to be_include('-  t.varchar :name, limit: 100')
        expect(output).to be_include('+  t.varchar :name, limit: 200')
        expect(output).to be_include(' create_table :users do |t|')
      end
    end

    context 'when nothing changed' do
      let(:tables) do
        { 'users' => Convergence::Table.new('users').tap { |t| t.int('id', primary_key: true) } }
      end

      it 'should return an empty string' do
        output = Convergence::PrettyDiff.new(tables, tables).output
        expect(output).to eq('')
      end
    end

    context 'when tables are added, removed, and changed at the same time' do
      let(:from_tables) do
        {
          'authors' => Convergence::Table.new('authors').tap { |t| t.int('id', primary_key: true) },
          'papers' => Convergence::Table.new('papers').tap { |t| t.varchar('title', limit: 100) }
        }
      end
      let(:to_tables) do
        {
          'papers' => Convergence::Table.new('papers').tap { |t| t.varchar('title', limit: 200) },
          'comments' => Convergence::Table.new('comments').tap { |t| t.int('id', primary_key: true) }
        }
      end

      it 'should show every add/remove/change table diff' do
        output = Convergence::PrettyDiff.new(from_tables, to_tables).output
        expect(output).to be_include('+ create_table :comments do |t|')
        expect(output).to be_include('- create_table :authors do |t|')
        expect(output).to be_include('-  t.varchar :title, limit: 100')
        expect(output).to be_include('+  t.varchar :title, limit: 200')
      end
    end
  end
end
