require 'spec_helper'
require 'convergence/config'
require 'tempfile'

describe Convergence::Config do
  describe '#initialize' do
    it 'sets the known attributes' do
      config = Convergence::Config.new(
        adapter: 'mysql2',
        database: 'my_db',
        host: '127.0.0.1',
        port: 3306,
        username: 'root',
        password: 'secret'
      )
      expect(config.adapter).to eq('mysql2')
      expect(config.database).to eq('my_db')
      expect(config.host).to eq('127.0.0.1')
      expect(config.port).to eq(3306)
      expect(config.username).to eq('root')
      expect(config.password).to eq('secret')
    end

    it 'ignores unknown attributes instead of raising' do
      expect { Convergence::Config.new(adapter: 'mysql2', unknown_key: 'value') }.not_to raise_error
    end

    it 'ignores nil-valued attributes' do
      config = Convergence::Config.new(adapter: 'mysql2', database: nil)
      expect(config.database).to be_nil
    end

    context 'when the adapter is mysql/mysql2' do
      it 'builds a nested MySQL SSL config object' do
        config = Convergence::Config.new(adapter: 'mysql2', sslca: '/path/to/ca.pem', sslverify: true)
        expect(config.mysql).to be_a(Convergence::Config::MySQL)
        expect(config.mysql.ssl_options).to eq(sslca: '/path/to/ca.pem', sslverify: true)
      end

      it 'omits unset SSL options from ssl_options' do
        config = Convergence::Config.new(adapter: 'mysql2')
        expect(config.mysql.ssl_options).to eq({})
      end
    end

    context 'when the adapter is not mysql/mysql2' do
      it 'does not build a MySQL SSL config object' do
        config = Convergence::Config.new(adapter: 'postgresql')
        expect(config.mysql).to be_nil
      end
    end
  end

  describe '.load' do
    it 'parses attributes from a YAML file' do
      Tempfile.create(['database', '.yml']) do |file|
        file.write("adapter: mysql2\ndatabase: my_db\nhost: 127.0.0.1\n")
        file.flush
        config = Convergence::Config.load(file.path)
        expect(config.adapter).to eq('mysql2')
        expect(config.database).to eq('my_db')
        expect(config.host).to eq('127.0.0.1')
      end
    end

    it 'evaluates ERB before parsing the YAML' do
      Tempfile.create(['database', '.yml']) do |file|
        file.write("adapter: mysql2\ndatabase: <%= 'interpolated_' + 'db' %>\n")
        file.flush
        config = Convergence::Config.load(file.path)
        expect(config.database).to eq('interpolated_db')
      end
    end
  end
end
