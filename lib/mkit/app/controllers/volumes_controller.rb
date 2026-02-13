# frozen_string_literal: true

require 'mkit/app/model/persistent_volume'

class VolumesController < MKIt::Server
  get '/volumes' do
    volumes = PersistentVolume.all
    volumes.map { |v| volume_response(v) }
  end

  get '/volumes/:id' do
    pv = find_volume_by_id_or_name
    volume_response(pv)
  end

  post '/volumes' do
    payload = JSON.parse(request.body.read)

    raise MKIt::InvalidConfigurationException, 'name is required' unless payload['name']
    raise MKIt::InvalidConfigurationException, 'capacity is required' unless payload['capacity']

    pv = PersistentVolume.create_volume(
      name: payload['name'],
      capacity: payload['capacity'],
      reclaim_policy: payload['reclaim_policy'] || 'Retain',
      storage_class: payload['storage_class'] || 'default'
    )

    volume_response(pv)
  end

  delete '/volumes/:id' do
    pv = find_volume_by_id_or_name
    pv.destroy
    { deleted: true }
  end

  private

  def find_volume_by_id_or_name
    pv = PersistentVolume.find_by(id: params[:id])
    pv ||= PersistentVolume.find_by(name: params[:id])
    raise MKIt::ServiceNotFoundException, "Volume not found: #{params[:id]}" unless pv

    pv
  end

  def volume_response(pv)
    {
      name: pv.name,
      capacity: pv.capacity,
      reclaim_policy: pv.reclaim_policy,
      storage_class: pv.storage_class,
      status: pv.status,
      volume_mode: pv.volume_mode,
      created_at: pv.created_at
    }
  end
end
