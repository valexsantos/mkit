# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2) do
  create_table "dns_hosts", force: :cascade do |t|
    t.string "service_id"
    t.string "pod_id"
    t.string "name"
    t.string "ip"
    t.string "ipv6"
  end

  create_table "leases", force: :cascade do |t|
    t.string "pool_id"
    t.string "service_id"
    t.string "interface_name"
    t.string "interface_type"
    t.string "status"
    t.string "ip"
    t.datetime "expires_at", precision: nil
  end

  create_table "mkit_jobs", force: :cascade do |t|
    t.string "topic"
    t.string "service_id"
    t.string "pod_id"
    t.string "status"
    t.string "retries"
    t.string "payload"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "pods", force: :cascade do |t|
    t.string "service_id"
    t.string "pod_id"
    t.string "name"
    t.string "ip"
    t.string "image"
    t.string "status"
  end

  create_table "pools", force: :cascade do |t|
    t.string "name"
    t.string "ip"
    t.string "range"
    t.string "netmask"
    t.string "status"
    t.boolean "preferred", default: false
  end

  create_table "service_configs", force: :cascade do |t|
    t.string "service_id"
    t.string "key"
    t.string "value"
    t.string "ctype"
    t.string "version"
  end

  create_table "service_ports", force: :cascade do |t|
    t.string "service_id"
    t.string "internal_port"
    t.string "external_port"
    t.string "mode"
    t.string "load_bal"
    t.string "version"
  end

  create_table "services", force: :cascade do |t|
    t.string "name"
    t.string "image"
    t.string "qdm"
    t.string "command"
    t.integer "max_replicas", default: 1
    t.integer "min_replicas", default: 1
    t.string "lease_id"
    t.string "pods_network", default: "mkit"
    t.string "version"
    t.string "status"
    t.datetime "created_at", precision: nil, default: "2023-12-28 12:41:59"
    t.datetime "updated_at", precision: nil
    t.index ["name"], name: "services_name_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "key"
    t.string "value"
  end

  create_table "volumes", force: :cascade do |t|
    t.string "service_id"
    t.string "name"
    t.string "path"
    t.string "ctype"
    t.string "status"
    t.string "version"
  end

end
