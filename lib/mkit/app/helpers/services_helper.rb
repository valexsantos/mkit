require 'text-table'
module MKIt
  module ServicesHelper
    def format_response(data, verbose = false)
      table = Text::Table.new
      if !data.respond_to?"each" || verbose
        table.head = ["id", "name", "addr", "ports", "pods", "status"]
      else
        table.head = ["id", "name", "addr", "ports", "pods", "status"]
      end
      if data.respond_to?"each"
         data.each { | srv |
           ports = srv.service_port&.each.map { |p| "#{p.mode}/#{p.external_port}"}.join(",")
           pods = srv.pod.each.map{ |p| "#{p.name}"}.join(" ")
           table.rows << [srv.id, srv.name, srv.lease&.ip, ports, pods, srv.status]
        }
      else
        ports = data.service_port&.each.map { |p| "#{p.mode}/#{p.external_port}"}.join(",")
        pods = data.pod.each.map{ |p| "#{p.name}"}.join(" ")
        table.rows <<  [data.id, data.name, data.lease&.ip, ports, pods, data.status]
      end
      table.to_s
    end

    def find_by_id_or_name
      srv = Service.find_by_id(params[:id])
      srv = Service.find_by_name(params[:id]) unless srv
      error 404, "Couldn't find Service '#{params[:id]}'\n" unless srv
      srv
    end

  end
end
