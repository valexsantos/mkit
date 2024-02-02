# frozen_string_literal: true

require 'mkit/app/model/mkit_job'

class MkitJobsController < MKIt::Server
  # curl localhost:4567/mkitjobs
  get '/mkitjobs' do
    JSON.pretty_generate(JSON.parse(MkitJob.all.to_json))
  end

  get '/mkitjobs/:id' do
    JSON.pretty_generate(JSON.parse(MkitJob.find(params[:id]).to_json))
  end

  put '/mkitjobs/:id' do
    "Not impleemnted\n"
  end

  delete '/mkitjobs/:id' do
    JSON.pretty_generate(JSON.parse(MkitJob.destroy(params[:id]).to_json))
  end

  delete '/mkitjobs/clean/all' do
    MkitJob.destroy_all
  end

  post '/mkitjobs' do
    xx = 'no file'
    if params[:file]
      tempfile = params[:file][:tempfile]
      xx = YAML.safe_load(tempfile.read)
      puts xx
    end
    JSON.pretty_generate(JSON.parse(xx.to_json))
  end
end
