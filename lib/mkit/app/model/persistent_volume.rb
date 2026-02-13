# frozen_string_literal: true

require 'openssl'
require 'base64'

class PersistentVolume < ActiveRecord::Base
  validates :name, presence: true, uniqueness: true
  validates :capacity, presence: true

  before_destroy :ensure_available

  enum status: { available: 'Available', bound: 'Bound', released: 'Released', failed: 'Failed' }
  enum reclaim_policy: { retain: 'Retain', delete: 'Delete' }

  def self.create_volume(name:, capacity:, reclaim_policy: 'Retain', storage_class: 'default')
    pv = PersistentVolume.new(
      name: name,
      capacity: capacity,
      reclaim_policy: reclaim_policy,
      storage_class: storage_class,
      status: 'Available'
    )
    pv.save!
    pv
  end

  def bind
    update(status: 'Bound')
  end

  def release
    update(status: 'Released')
  end

  private

  def ensure_available
    return if available?

    errors.add(:base, "Cannot delete volume in status #{status}")
    throw(:abort)
  end
end
