# frozen_string_literal: true

require_relative 'spec_helper'

describe PersistentVolume do
  let(:volume) do
    PersistentVolume.create_volume(
      name: 'my-data',
      capacity: '10Gi',
      reclaim_policy: 'Retain',
      storage_class: 'default'
    )
  end

  it 'creates a persistent volume' do
    assert volume.persisted?
    assert_equal 'my-data', volume.name
    assert_equal '10Gi', volume.capacity
    assert_equal 'Retain', volume.reclaim_policy
    assert_equal 'default', volume.storage_class
  end

  it 'has default status Available' do
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

  it 'cannot delete when bound' do
    volume.bind
    volume.reload
    assert_raises(ActiveRecord::RecordNotDestroyed) do
      volume.destroy!
    end
  end

  it 'can delete when Available' do
    volume.destroy
    refute PersistentVolume.exists?(volume.id)
  end

  it 'validates uniqueness of name' do
    assert_raises(ActiveRecord::RecordInvalid) do
      PersistentVolume.create_volume(
        name: 'my-data',
        capacity: '20Gi'
      )
    end
  end

  it 'validates presence of name' do
    assert_raises(ActiveRecord::RecordInvalid) do
      PersistentVolume.create_volume(name: '', capacity: '10Gi')
    end
  end

  it 'validates presence of capacity' do
    assert_raises(ActiveRecord::RecordInvalid) do
      PersistentVolume.create_volume(name: 'vol', capacity: '')
    end
  end
end
