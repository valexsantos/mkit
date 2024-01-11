require 'mkit/ctypes'
require 'mkit/app/helpers/docker_helper'
require 'fileutils'

class Volume < ActiveRecord::Base
  belongs_to :service
  before_destroy :clean_up

  def self.create(service, volume)
        case volume
        when /^docker:\/\//
          ctype = MKIt::CType::DOCKER_STORAGE
          paths = volume[9..].split(':')
          # vname="#{service.name}.#{service.application.name}.#{paths[0]}"
          vname = paths[0]
        when /^\//
          ctype = MKIt::CType::LOCAL_STORAGE
          paths = volume.split(':')
          vname = paths[0]
        end
        Volume.new(
          service: service,
          name: vname,
          path: paths[1],
          ctype: ctype
        )
  end

  def deploy
    create_volume
  end

  def create_volume
    case self.ctype
    when MKIt::CType::DOCKER_STORAGE
      MKIt::DockerHelper.create_volume(self.name)
    when MKIt::CType::LOCAL_STORAGE
      # nop
    end
  end

  def delete_volume
    case self.ctype
    when MKIt::CType::DOCKER_STORAGE
      MKIt::DockerHelper.delete_volume(self.name)
    end
  end

  def clean_up
    # nop
  end
end

