require 'erb'
require 'mkit/config/config'
module MKIt
  module Utils
    module_function

    MKIT_CRT = 'mkit.crt'
    MKIT_KEY = 'mkit.key'
    MKIT_PEM = 'mkit.pem'

    def me
      'mkit'
    end

    def log
      Console.logger
    end

    def root
      File.expand_path("../../..", __FILE__)
    end

    def set_config_dir(config_dir)
      @config_dir = config_dir
    end

    def config_dir
      @config_dir.nil? ? "#{self.root}/config" : @config_dir
    end

    def proxy_cert
      "#{config_dir}/#{MKIT_PEM}"
    end

    def load_db_config(db_config_dir = self.config_dir)
      self.log.info "loading database configurations from '#{config_dir}'..."
      YAML::load(ERB.new(IO.read("#{db_config_dir}/database.yml")).result)
    end

    def db_config_to_uri(env = MKIt::Config.mkit.database.env)
      config = self.load_db_config[env]

      if config["username"] || config["password"]
        user_info = [ config["username"], config["password"] ].join(":")
      else
        user_info = nil
      end
      URI::Generic.new(config["adapter"],user_info,
                       config["hostname"] || "localhost",
                       config["port"],
                       nil,
                       "/#{config["database"]}",
                       nil,
                       nil,
                       nil).to_s
    end
  end
end

