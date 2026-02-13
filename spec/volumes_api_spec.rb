# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Volumes API' do
  include Rack::Test::Methods

  def app
    MKIt::Server
  end

  describe 'GET /volumes' do
    it 'returns empty array when no volumes' do
      get '/volumes'
      assert_equal 200, last_response.status
      assert_equal [], JSON.parse(last_response.body)
    end

    it 'lists all volumes' do
      PersistentVolume.create_volume(name: 'vol1', capacity: '10Gi')
      PersistentVolume.create_volume(name: 'vol2', capacity: '20Gi')

      get '/volumes'
      assert_equal 200, last_response.status
      volumes = JSON.parse(last_response.body)
      assert_equal 2, volumes.size
    end
  end

  describe 'GET /volumes/:id' do
    let(:volume) { PersistentVolume.create_volume(name: 'test-vol', capacity: '10Gi') }

    it 'returns volume by id' do
      get "/volumes/#{volume.id}"
      assert_equal 200, last_response.status
      data = JSON.parse(last_response.body)
      assert_equal 'test-vol', data['name']
    end

    it 'returns volume by name' do
      get '/volumes/test-vol'
      assert_equal 200, last_response.status
      data = JSON.parse(last_response.body)
      assert_equal 'test-vol', data['name']
    end

    it 'returns 404 for non-existent' do
      get '/volumes/non-existent'
      assert_equal 404, last_response.status
    end
  end

  describe 'POST /volumes' do
    it 'creates volume' do
      post '/volumes', JSON.dump({
                                   name: 'new-vol',
                                   capacity: '10Gi'
                                 }), 'CONTENT_TYPE' => 'application/json'

      assert_equal 200, last_response.status
      assert PersistentVolume.exists?(name: 'new-vol')
    end

    it 'creates volume with custom reclaim policy' do
      post '/volumes', JSON.dump({
                                   name: 'delete-vol',
                                   capacity: '10Gi',
                                   reclaim_policy: 'Delete'
                                 }), 'CONTENT_TYPE' => 'application/json'

      assert_equal 200, last_response.status
      vol = PersistentVolume.find_by(name: 'delete-vol')
      assert_equal 'Delete', vol.reclaim_policy
    end

    it 'creates volume with storage class' do
      post '/volumes', JSON.dump({
                                   name: 'ssd-vol',
                                   capacity: '10Gi',
                                   storage_class: 'ssd'
                                 }), 'CONTENT_TYPE' => 'application/json'

      assert_equal 200, last_response.status
      vol = PersistentVolume.find_by(name: 'ssd-vol')
      assert_equal 'ssd', vol.storage_class
    end

    it 'validates required fields' do
      post '/volumes', JSON.dump({ name: 'vol' }), 'CONTENT_TYPE' => 'application/json'
      assert_equal 400, last_response.status
    end

    it 'validates unique name' do
      PersistentVolume.create_volume(name: 'existing', capacity: '10Gi')

      post '/volumes', JSON.dump({
                                   name: 'existing',
                                   capacity: '20Gi'
                                 }), 'CONTENT_TYPE' => 'application/json'

      assert_equal 400, last_response.status
    end
  end

  describe 'DELETE /volumes/:id' do
    let(:volume) { PersistentVolume.create_volume(name: 'to-delete', capacity: '10Gi') }

    it 'deletes available volume' do
      delete "/volumes/#{volume.id}"
      assert_equal 200, last_response.status
      refute PersistentVolume.exists?(volume.id)
    end

    it 'cannot delete bound volume' do
      volume.bind

      delete "/volumes/#{volume.id}"
      assert_equal 400, last_response.status
      assert_match(/Cannot delete/, last_response.body)
    end

    it 'returns 404 for non-existent' do
      delete '/volumes/non-existent'
      assert_equal 404, last_response.status
    end
  end

  describe 'Volume lifecycle' do
    let(:volume) { PersistentVolume.create_volume(name: 'lifecycle-test', capacity: '10Gi') }

    it 'starts as available' do
      assert_equal 'Available', volume.status
    end

    it 'can be bound' do
      volume.bind
      assert_equal 'Bound', volume.status
    end

    it 'can be released' do
      volume.bind
      volume.release
      assert_equal 'Released', volume.status
    end
  end
end
