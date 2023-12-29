require 'mkit/app/model/setting'
require 'mkit/app/model/pool'
require 'mkit/config/config'
require 'fileutils'
require 'mkit/utils'

module MKIt
  module Initializers

    def self.load_my_configuration(config_dir: MKIt::Utils.config_dir)
      MKIt::Utils.log.info "loading configurations from '#{config_dir}'..."
      MKIt::Config.load_yml!("#{config_dir}/mkit_config.yml")
    end

    def self.load_default_configs
      if Pool.find_by_name(MKIt::Utils.me).nil?
        st = Pool.new(
          name: MKIt::Utils.me,
          ip: MKIt::Config.mkit.my_network.ip,
          range: '10-200',
          netmask: '24',
          preferred: true
        )
        st.save
      end
    end
  end
end

