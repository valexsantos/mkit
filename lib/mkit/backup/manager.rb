# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'yaml'

module MKIt
  module Backup
    class Manager
      DEFAULT_BACKUP_DIR = '/var/lib/mkitd/backups'

      def initialize(backup_dir: DEFAULT_BACKUP_DIR)
        @backup_dir = backup_dir
        FileUtils.mkdir_p(@backup_dir)
      end

      def backup(name = nil)
        timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
        backup_name = name || "mkit_backup_#{timestamp}"
        backup_path = File.join(@backup_dir, "#{backup_name}.tar.gz")

        temp_dir = File.join(@backup_dir, backup_name)
        FileUtils.mkdir_p(temp_dir)

        begin
          export_services(File.join(temp_dir, 'services.yaml'))
          export_pods(File.join(temp_dir, 'pods.yaml'))
          export_secrets(File.join(temp_dir, 'secrets.yaml'))
          export_config(File.join(temp_dir, 'config.yaml'))

          create_archive(temp_dir, backup_path)
          FileUtils.rm_rf(temp_dir)

          MKItLogger.info("Backup created: #{backup_path}")
          { success: true, path: backup_path, name: backup_name }
        rescue StandardError => e
          FileUtils.rm_rf(temp_dir)
          MKItLogger.error("Backup failed: #{e.message}")
          { success: false, error: e.message }
        end
      end

      def restore(backup_path)
        return { success: false, error: 'Backup file not found' } unless File.exist?(backup_path)

        temp_dir = File.join(@backup_dir, "restore_#{$$}")

        begin
          extract_archive(backup_path, temp_dir)

          ActiveRecord::Base.transaction do
            import_services(File.join(temp_dir, 'services.yaml'))
            import_pods(File.join(temp_dir, 'pods.yaml'))
            import_secrets(File.join(temp_dir, 'secrets.yaml'))
          end

          FileUtils.rm_rf(temp_dir)
          MKItLogger.info("Restore completed from: #{backup_path}")
          { success: true }
        rescue StandardError => e
          FileUtils.rm_rf(temp_dir)
          MKItLogger.error("Restore failed: #{e.message}")
          { success: false, error: e.message }
        end
      end

      def list
        Dir.glob(File.join(@backup_dir, '*.tar.gz'))
           .sort
           .reverse
           .map { |f| { name: File.basename(f), path: f, created: File.mtime(f) } }
      end

      private

      def export_services(path)
        services = Service.all.map(&:to_h)
        File.write(path, services.to_yaml)
      end

      def export_pods(path)
        pods = Pod.all.map do |pod|
          {
            name: pod.name,
            ip: pod.ip,
            status: pod.status,
            service_id: pod.service_id,
            version: pod.version
          }
        end
        File.write(path, pods.to_yaml)
      end

      def export_secrets(path)
        secrets = Secret.all.map do |s|
          { name: s.name, key: s.key, ctype: s.ctype, service_id: s.service_id }
        end
        File.write(path, secrets.to_yaml)
      end

      def export_config(path)
        config_data = {}
        begin
          config_data = YAML.safe_load(File.read(MKIt::Config.config_file))
        rescue StandardError
          config_data = {}
        end

        config = {
          version: MKIt::VERSION,
          timestamp: Time.now.iso8601,
          mkit_config: config_data
        }
        File.write(path, config.to_yaml)
      end

      def import_services(path)
        return unless File.exist?(path)

        YAML.safe_load(File.read(path))&.each do |srv|
            Service.create(srv)
        rescue StandardError
            nil
        end
      end

      def import_pods(path)
        return unless File.exist?(path)

        YAML.safe_load(File.read(path))&.each do |pod|
            Pod.create(pod)
        rescue StandardError
            nil
        end
      end

      def import_secrets(path)
        return unless File.exist?(path)

        YAML.safe_load(File.read(path))&.each do |secret|
            Secret.create(secret.except('value'))
        rescue StandardError
            nil
        end
      end

      def create_archive(source_dir, dest_path)
        system("tar -czf #{dest_path} -C #{source_dir} .")
      end

      def extract_archive(source_path, dest_dir)
        FileUtils.mkdir_p(dest_dir)
        system("tar -xzf #{source_path} -C #{dest_dir}")
      end
    end
  end
end
