require 'spec_helper'
require 'convergence/dumper/mysql_schema_dumper'
require 'convergence/database_connector'

describe Convergence::Dumper::MysqlSchemaDumper do
  before do
    # load fixtures
  end
  let(:connector) do
    Convergence::DatabaseConnector.new(mysql_settings)
  end
  let(:dumper) do
    Convergence::Dumper::MysqlSchemaDumper.new(connector)
  end

  describe '#dump' do
    subject { dumper.dump }

    it 'should be dump tables' do
      expect(subject['papers']).not_to be_nil
      expect(subject['authors']).not_to be_nil
      expect(subject['paper_authors']).not_to be_nil
    end

    describe 'table options' do
      it 'shoulb be dump options' do
        papers = subject['papers']
        expect(papers.table_options[:engine]).to eq('InnoDB')
        expect(papers.table_options[:comment]).to eq('Paper')
      end
    end

    describe 'table columns' do
      it 'should be dump table columns' do
        papers = subject['papers']
        expect(papers.columns['id']).not_to be_nil
        expect(papers.columns['title1']).not_to be_nil
        expect(papers.columns['title2']).not_to be_nil
        expect(papers.columns['description']).not_to be_nil
        expect(papers.columns['edition_number']).not_to be_nil
        expect(papers.columns['published_at']).not_to be_nil
      end

      it 'should be dump columns in the correct order' do
        papers = subject['papers']
        expect(papers.columns.keys)
          .to eq(%w(id slug title1 title2 description edition_number published_at))
      end

      describe 'table column options' do
        it 'should be dump primary key' do
          expect(subject['papers'].columns['id'].options[:primary_key]).to be_truthy
        end

        it 'should be dump extra' do
          expect(subject['papers'].columns['id'].options[:extra]).to eq('auto_increment')
        end

        it 'should be dump comment' do
          expect(subject['papers'].columns['title1'].options[:comment]).to eq('Title 1')
        end

        it 'should be dump limit' do
          expect(subject['papers'].columns['title1'].options[:limit]).to eq('300')
        end

        it 'should be dump not null definition' do
          expect(subject['papers'].columns['title1'].options[:null]).to be_falsy
          expect(subject['authors'].columns['created_at'].options[:null]).to be_truthy
        end

        it 'should be dump unsigned definition' do
          expect(subject['authors'].columns['age'].options[:unsigned]).to be_truthy
        end

        it 'should be dump default' do
          expect(subject['papers'].columns['edition_number'].options[:default]).to eq "0"
          expect(subject['papers'].columns['published_at'].options[:default])
            .to be_a(Proc)
            .and have_attributes(call: "CURRENT_TIMESTAMP")
        end
      end
    end

    describe 'indexes' do
      it 'should be dump index of authors' do
        index = subject['authors'].indexes['index_authors_on_created_at']
        expect(index).not_to be_nil
        expect(index.index_columns).to eq(['created_at'])
        expect(index.options[:unique]).to eq(false)
      end

      it 'should be dump unique index of papers' do
        index = subject['papers'].indexes['index_papers_on_slug']
        expect(index).not_to be_nil
        expect(index.index_columns).to eq(['slug'])
        expect(index.options[:unique]).to eq(true)
      end

      it 'should be dump non-unique index of papers' do
        index = subject['papers'].indexes['index_papers_on_title1_title2']
        expect(index).not_to be_nil
        expect(index.index_columns).to eq(['title1', 'title2'])
        expect(index.options[:length]).to eq('title1' => 100, 'title2' => 200)
        expect(index.options[:unique]).to eq(false)
      end
    end

    describe 'foreign keys' do
      it do
        foreign_key = subject['paper_authors'].foreign_keys['paper_authors_author_id_fk']
        expect(foreign_key).not_to be_nil
        expect(foreign_key.from_columns).to eq(['author_id'])
        expect(foreign_key.to_table).to eq('authors')
        expect(foreign_key.to_columns).to eq(['id'])
      end
    end
  end
end
