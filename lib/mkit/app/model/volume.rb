# frozen_string_literal: true

require 'mkit/ctypes'
require 'mkit/app/helpers/docker_helper'
require 'mkit/app/model/persistent_volume'
require 'fileutils'

class Volume < ActiveRecord::Base
  belongs_to :service
  before_destroy :clean_up

  def self.create(service, volume)
    case volume
    when %r{^docker://}
      ctype = MKIt::CType::DOCKER_STORAGE
      paths = volume[9..].split(':')
      vname = paths[0]
    when %r{^/}
      ctype = MKIt::CType::LOCAL_STORAGE
      paths = volume.split(':')
      vname = paths[0]
    when %r{^persistent://}
      ctype = MKIt::CType::PERSISTENT_VOLUME
      paths = volume[12..].split(':')
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
    case ctype
    when MKIt::CType::DOCKER_STORAGE
      MKIt::DockerHelper.create_volume(name)
    when MKIt::CType::PERSISTENT_VOLUME
      pv = PersistentVolume.find_by(name: name)
      return unless pv

      pv.bind if pv.available?
    when MKIt::CType::LOCAL_STORAGE
      # nop
    end
  end

  def delete_volume
    case ctype
    when MKIt::CType::DOCKER_STORAGE
      MKIt::DockerHelper.delete_volume(name)
    when MKIt::CType::PERSISTENT_VOLUME
      pv = PersistentVolume.find_by(name: name)
      return unless pv

      if pv.retain?
        pv.release
      elsif pv.delete?
        pv.destroy
      end
    end
  end

  def clean_up
    # nop
  end
end
