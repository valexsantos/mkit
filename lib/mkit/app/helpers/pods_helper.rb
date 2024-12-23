# frozen_string_literal: true

module MKIt
  module PodsHelper

    def find_by_id_or_name
      pod = Pod.find_by_id(params[:id])
      pod ||= Pod.find_by_name(params[:id])
      error 404, "Couldn't find Pod '#{params[:id]}'\n" unless pod
      pod
    end

  end
end
