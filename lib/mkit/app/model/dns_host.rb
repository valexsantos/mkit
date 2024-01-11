require 'mkit/status'
require 'mkit/exceptions'
require 'mkit/app/model/service'
require 'mkit/app/model/pod'
require 'mkit/app/helpers/interface_helper'

class DnsHost < ActiveRecord::Base
  belongs_to :service
  belongs_to :pod
end

