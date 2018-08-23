require 'spec_helper'
require 'convergence/dsl'

describe Convergence::DSL do
  let(:dsl_single_table) do
    <<-DSL
    create_table "users", comment: 'Users' do |t|
      t.int "id", primary_key: true, null: false, limit: 11, extra: "auto_increment"
      t.varchar "email"
      t.varchar "first_name"
      t.varchar "last_name"
      t.int "age", unsigned: true
      t.datetime "created_at", null: true

      t.index 'email', length: 100
      t.index ['first_name', 'last_name'], length: { first_name: 15, last_name: 20 }
      t.index 'created_at'
      t.foreign_key "user_id", reference: "users", reference_column: "id"
    end
    DSL
  end

  let(:dsl_multi_table) do
    <<-DSL
    create_table "users", comment: 'Users' do |t|
      t.int "id", primary_key: true, extra: "auto_increment"
      t.varchar "name", limit: 100
      t.datetime "created_at", null: true
    end

    create_table "posts", comment: "Posts" do |t|
      t.int "id", primary_key: true, extra: "auto_increment"
      t.int "user_id"
      t.datetime "created_at", null: true

      t.foreign_key "user_id", reference: "users", reference_column: "id"
    end
    DSL
  end

  describe '#parse' do
    context 'when exist only one table' do
      subject { Convergence::DSL.parse(dsl_single_table, '') }

      it 'should be able to parse tables' do
        expect(subject['users']).not_to be_nil
      end

      it 'should be able to parse table options' do
        expect(subject['users'].table_options[:comment]).to eq('Users')
      end

      it 'should be able to parse table columns' do
        columns = subject['users'].columns
        expect(columns['id']).not_to be_nil
        expect(columns['created_at']).not_to be_nil
      end

      it 'should be able to parse table column options' do
        columns = subject['users'].columns
        expect(columns['id'].options[:primary_key]).to be_truthy
        expect(columns['id'].options[:null]).to be_falsy
        expect(columns['id'].options[:limit]).to eq(11)
        expect(columns['id'].options[:extra]).to eq('auto_increment')
        expect(columns['age'].options[:unsigned]).to be_truthy
      end

      it 'should be able to parse indexes' do
        indexes = subject['users'].indexes
        expect(indexes).not_to be_nil
        expect(indexes['index_users_on_email']).not_to be_nil
        expect(indexes['index_users_on_email'].options[:length]['email']).to eq(100)
        expect(indexes['index_users_on_first_name_last_name']).not_to be_nil
        expect(indexes['index_users_on_first_name_last_name'].options[:length]['first_name']).to eq(15)
        expect(indexes['index_users_on_first_name_last_name'].options[:length]['last_name']).to eq(20)
      end

      it 'should be able to parse foreign keys' do
        expect(subject['users'].foreign_keys).not_to be_nil
      end
    end

    context 'when multiple tables exists' do
      subject { Convergence::DSL.parse(dsl_multi_table, '') }

      it 'should be able to parse tables' do
        expect(subject['users']).not_to be_nil
        expect(subject['posts']).not_to be_nil
      end
    end
  end
end
