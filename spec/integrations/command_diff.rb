require 'spec_helper'
require 'convergence/command/diff'

describe 'Command::Diff#execute' do
  def execute(file1, file2)
    opts = {
      diff: [
        File.expand_path("#{File.dirname(__FILE__)}/../fixtures/#{file1}"),
        File.expand_path("#{File.dirname(__FILE__)}/../fixtures/#{file2}")
      ]
    }
    Convergence::Command::Diff.new(opts, config: nil).execute
  end

  it 'should show tables only present in the second file as added' do
    result = execute('drop_table.schema', 'add_table.schema')
    expect(result).to be_include('+ create_table :paper_authors, collate: "utf8_general_ci", comment: "Paper Author Relation" do |t|')
  end

  it 'should show tables only present in the first file as removed' do
    result = execute('add_table.schema', 'drop_table.schema')
    expect(result).to be_include('- create_table :paper_authors, collate: "utf8_general_ci", comment: "Paper Author Relation" do |t|')
  end

  it 'should show a column change between the two files as a unified diff' do
    result = execute('add_table.schema', 'change_comment_columns_to_paper.schema')
    expect(result).to be_include("-  t.datetime :created_at, null: true\n")
    expect(result).to be_include("+  t.datetime :created_at, null: true, comment: \"Created At\"\n")
  end

  it 'should be empty when comparing a schema file with itself' do
    result = execute('add_table.schema', 'add_table.schema')
    expect(result).to eq('')
  end
end
