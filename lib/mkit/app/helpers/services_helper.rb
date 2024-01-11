module MKIt
  module ServicesHelper
    def str_template
      "%-5s   %-18s   %-15s  %-25s  %-10s"
    end

    def header_template
      ["id", "name", "addr", "ports", "status"]
    end

    def _format(template, data)
      template % data
    end

    def format_response(data, verbose = false)
      resp = []
      header = _format(str_template, header_template)
      resp << header
      if data.respond_to?"each"
        data.each { | srv |
          ports = srv.service_port&.each.map { |p| "#{p.mode}/#{p.external_port}"}.join(",")
          resp << _format(str_template, [srv.id, srv.name, srv.lease&.ip, ports, srv.status])
          resp+=service_pods(srv) if verbose
        }
      else
        ports = data.service_port&.each.map { |p| "#{p.mode}/#{p.external_port}"}.join(",")
        resp << _format(str_template, [data.id, data.name, data.lease&.ip, ports, data.status])
        resp+=service_pods(data)
      end
      resp << ""
      resp.join("\n")
    end

    def service_pods(srv)
      resp=[]
      resp << "  pods"
      resp << _format("    %-5s   %-15s   %-15s   %-15s   %-10s", ["id", "pod_id", "pod_name", "pod_ip", "status"])
      srv.pod.each { |pod|
        name = pod.name.nil? ? "" : pod.name[0..11]
        pod_id = pod.pod_id.nil? ? "" : pod.pod_id[0..11]
        resp << _format("    %-5s   %-15s   %-15s   %-15s   %-10s", [pod.id, pod_id, name, pod.ip, pod.status])
      }
      resp
    end

    def find_by_id_or_name
      srv = Service.find_by_id(params[:id])
      srv = Service.find_by_name(params[:id]) unless srv
      error 404, "Couldn't find Service '#{params[:id]}'\n" unless srv
      srv
    end

  end
end
