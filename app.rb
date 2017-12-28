# frozen_string_literal: true

require 'sinatra'
require "#{File.dirname(__FILE__)}/lib/pem"
require "#{File.dirname(__FILE__)}/lib/pemenv"

# Create Pem App
class PemApp < Sinatra::Base
  # Assuming these go someplace useful in future
  logger = Logger.new(STDOUT)

  # Create a new PEM instance
  pem = Pem.new(logger)

  set :public_folder, 'pem_ui'

  get "/" do
    redirect '/index.html'
  end

  # List all envs
  #
  # Request
  #   GET /envs
  #
  # Response
  #   {
  #     "test6": {
  #       "concat": "4.1.1",
  #       "ntp": "6.4.1",
  #       "teamx": "ced1b6"
  #     }
  #   }
  get '/envs' do
    content_type 'application/json'
    pem.envs.to_json
  end

  # Deploy a global module
  #
  # Request
  #  POST /deploy_mod
  #  {
  #     "myorg-ntp": {
  #       "version": "e93a55d",
  #       "type": "git",
  #       "source": "https://github.com/ipcrm/ipcrm-ntp.git"
  #     }
  #   }
  # Response
  #   {
  #     "status":"successful"
  #   }
  #
  post '/deploy_mod' do
    content_type 'application/json'
    data = JSON.parse(request.body.read)

    begin
      data.each do |m, v|
        pem.deploy_mod(m, v)
      end
      { 'status' => 'successful' }.to_json
    rescue StandardError
      { 'status' => 'failed' }.to_json
    end
  end

  # Delete a global module
  #
  # Request
  #  POST /delete_mod
  #  {
  #     "myorg-ntp": {
  #       "version": "e93a55d"
  #     }
  #   }
  # Response
  #   {
  #     "status":"successful"
  #   }
  #   {
  #     "status":"failed", "envs": ["test3"]
  #   }
  #
  post '/purge_mod' do
    content_type 'application/json'
    data = JSON.parse(request.body.read)

    m = data.keys[0]
    v = data[m]['version']

    begin
      mod_status = pem.check_mod_use(m, v)
      if mod_status['status']
        { 'status' => 'failed', 'envs' => mod_status['envs'] }.to_json
      else
        pem.purge_mod(m, v['version'])
        { 'status' => 'successful' }.to_json
      end
    end
  end

  # Get global modules
  #
  # Request
  #   GET /modules
  # Response
  #  {
  #    "fake-module": [
  #      "0.5.0"
  #      "0.5.1"
  #      "0.7.3"
  #    ],
  #    "andulla-vsphere_conf": [
  #      "0.0.9"
  #    ],
  #    "mod-fake": [
  #      "d5f324",
  #      "ae54f3"
  #    ],
  #    "aristanetworks-netdev_stdlib_eos": [
  #      "1.2.0"
  #    ]
  #  }
  get '/modules' do
    content_type 'application/json'
    pem.modules.to_json
  end

  # Create an environment
  #
  # Request
  #   POST /envs/testenv/create
  #   {
  #     "myorg-teamx": "ced1b64",
  #     "puppetlabs-ntp": "6.4.1",
  #     "puppetlabs-concat": "4.1.1"
  #   }
  # Response
  #   {
  #     "status":"successful"
  #   }
  post '/envs/:name/create' do
    content_type 'application/json'
    data = JSON.parse(request.body.read)
    e = PemEnv.new(params[:name], pem)

    begin
      e.deploy(data)
      { 'status' => 'successful' }.to_json
    rescue StandardError
      { 'status' => 'failed' }.to_json
    end
  end

  # Get modules for configured enviornment
  #
  # Request
  #   GET /envs/testenv/modules
  # Response
  #   {
  #     "concat": "4.1.1",
  #     "ntp": "6.4.1",
  #     "teamx": "ced1b6"
  #   }
  get '/envs/:name/modules' do
    content_type 'application/json'
    e = PemEnv.new(params[:name], pem)
    e.mods.to_json
  end

  # Compare two environments
  #
  # Request
  #   POST /envs/compare
  #   [
  #     "test6",
  #     "test7"
  #   ]
  # Response
  #   {
  #     "ntp": {
  #       "test6": "6.4.1",
  #       "test7": "6.4.4"
  #     }
  #   }
  post '/envs/compare' do
    content_type 'application/json'
    data = JSON.parse(request.body.read)
    pem.compare_envs(data[0], data[1]).to_json
  end

  # Find enviornment a module is deployed to
  #
  # Request
  #  POST /find_mod_envs
  #  {
  #    "myorg-ntp": "e93a55d",
  #  }
  # Response
  #   {
  #     "status": true, "envs": [ "test1", "test2" ]
  #   }
  post '/find_mod_envs' do
    content_type 'application/json'
    data = JSON.parse(request.body.read)
    pem.find_module(data.keys[0], data[ data.keys[0] ]).to_json
  end
end