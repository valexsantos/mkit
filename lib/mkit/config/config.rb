require 'yaml'
#
# MKIt::Config.load_yml!('samples/mkit.yml')
# MKIt::Config.application.services
#  requires Hash.to_o
module MKIt
  module Config
    extend self

    def load_yml!(path)
      @config_file = path
      @config = YAML.load(File.new(path).read).to_o
    end

    def config_file
      @config_file
    end
    # 
    def method_missing(name,*args)
      return @config.send(name,*args)
    end
  end
end
