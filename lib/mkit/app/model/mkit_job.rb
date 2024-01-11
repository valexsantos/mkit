
require 'mkit/app/helpers/erb_helper'
require 'mkit/app/helpers/docker_helper'
require 'mkit/app/model/service'
require 'mkit/status'

class MkitJob < ActiveRecord::Base
  before_destroy :clean_up

  STATUS = %w{READY PROCESSING FAILED}

  def self.take
    MkitJob.where(status: 'READY').group(:service_id, :pod_id).take
  end

  def self.publish(*args)
    job = MkitJob.new(args[0])
    job.status = 'READY'
    job.save
    job
  end

  def processing!
    self.status='PROCESSING'
    self.save
  end

  def error!
    self.status='FAILED'
    self.save
  end

  def data=(opt={})
    self.payload=opt.to_json
  end

  def data
    JSON.parse(self.payload)
  end

  def done!
    self.destroy
  end

  def clean_up
  end

end
