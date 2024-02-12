# frozen_string_literal: true

require 'text-table'
module MKIt
  module ServicesHelper
    def format_response(data, _verbose = false)
      table = Text::Table.new
      table.head = %w[id name addr ports pods status]
      if data.respond_to? 'each'
        data.each do |srv|
          table.rows << build_table_row(srv)
        end
      else
        table.rows << build_table_row(data)
      end
      table.to_s
    end

    def find_by_id_or_name
      srv = Service.find_by_id(params[:id])
      srv ||= Service.find_by_name(params[:id])
      error 404, "Couldn't find Service '#{params[:id]}'\n" unless srv
      srv
    end

    def build_table_row(data)
      ports = data.service_port&.each.map { |p| "#{p.mode}/#{p.external_port}" }.join(',')
      pods = data.pod.each.map { |p| p.name.to_s }.join(' ')
      [data.id, data.name, data.lease&.ip, ports, pods, data.status]
    end
  end
end
