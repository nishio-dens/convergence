require 'erb'
require 'yaml'

class Convergence::Config
  ATTRIBUTES = %i[adapter database host port username password].freeze

  attr_accessor(*ATTRIBUTES, :mysql)

  class MySQL
    ATTRIBUTES = %i[ssl_mode sslkey sslcert sslca sslcapath sslcipher sslverify].freeze

    attr_accessor(*ATTRIBUTES)

    def initialize(attributes)
      attributes.each do |k, v|
        next if v.nil?
        next if !ATTRIBUTES.include?(k.to_sym) && !ATTRIBUTES.include?(k.to_s)
        instance_variable_set("@#{k}", v)
      end
    end

    def ssl_options
      {
        ssl_mode: ssl_mode,
        sslkey: sslkey,
        sslcert: sslcert,
        sslca: sslca,
        sslcapath: sslcapath,
        sslcipher: sslcipher,
        sslverify: sslverify
      }.compact
    end
  end

  def initialize(attributes)
    attributes.each do |k, v|
      next if v.nil?
      next if !ATTRIBUTES.include?(k.to_sym) && !ATTRIBUTES.include?(k.to_s)
      instance_variable_set("@#{k}", v)
    end
    case adapter
    when 'mysql', 'mysql2'
      @mysql = MySQL.new(attributes)
    end
  end

  def self.load(yaml_path)
    setting = YAML.safe_load(ERB.new(File.read(yaml_path)).result, [], [], true)
    new(setting)
  end
end
