# frozen_string_literal: true

class MigrateResources < ActiveRecord::Migration[5.1]

  #
  # migrate the resource data from service
  #
  def up
    Service.all.each do |service|
      resource = Resource.new
      resource.max_replicas = service.max_replicas
      resource.min_replicas = service.min_replicas
      service.resource = resource
    end
  end
end