require 'erb'
require 'yaml'

class Convergence::Config
  attr_accessor :adapter, :database, :host, :port, :username, :password

  def initialize(attributes)
    attributes.each do |k, v|
      instance_variable_set("@#{k}", v) unless v.nil?
    end
  end

  def self.load(yaml_path)
    setting = YAML.load(ERB.new(File.read(yaml_path)).result)
    new(setting)
  end
end
