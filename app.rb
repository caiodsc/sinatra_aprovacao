# Encoding: utf-8
require 'rubygems'
require 'bundler'

Bundler.require

require 'sinatra'
require 'mongoid'
require 'roar/json/hal'
require 'rack/conneg'
require 'yaml'

configure do
  Mongoid.load!("config/mongoid.yml", settings.environment)
  set :server, :puma # default to puma for performance
end

configure :development, :test do
  require_relative './dev.rb'
  #@venv = YAML.load(File.read('./config/config.yml'))
end

configure :production do
  require_relative './prd.rb'
  #@venv = YAML.load(File.read('./config/config.yml'))['environment']['prd']
end

use(Rack::Conneg) { |conneg|
  conneg.set :accept_all_extensions, false
  conneg.set :fallback, :json
  conneg.provide([:json])
}

before do
  if negotiated?
    content_type negotiated_type
  end
end

class Product
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :name, type: String
end

module ProductRepresenter
  include Roar::JSON::HAL
  
  property :name
  property :created_at, :writeable=>false

  link :self do
    "/products/#{id}"
  end
end
class App < Sinatra::Base

  before do
    if self.class.development?
      #@venv = YAML.load(File.read('./config/config.yml'))
    end
    if self.class.production?
      #p "Production"
    end

  end

  get '/' do

    #p @venv["environment"]
    #return "Teste"
    redirect request.base_url + '/home'
  end

  get '/home' do
    #"Hello world!"
    erb :home, :layout => :z_index

  end

  get '/products/?' do
    products = Product.all.order_by(:created_at => 'desc')
    ProductRepresenter.for_collection.prepare(products).to_json
  end

  get 'product/:id' do
    product = Product.where(name: 'Joao')
    ProductRepresenter.for_collection.prepare(product).to_json
  end

  post '/produto' do
    name = 'Joao2'
    #params[:name]

    if name.nil? or name.empty?
      halt 400, {:message=>"name field cannot be empty"}.to_json
    end

    product = Product.new(:name=>name)
    if product.save
      [201, product.extend(ProductRepresenter).to_json]
    else
      [500, {:message=>"Failed to save product"}.to_json]
    end
  end

  post '/products' do
    name = 'Caio'
        #params[:name]

    if name.nil? or name.empty?
      halt 400, {:message=>"name field cannot be empty"}.to_json
    end

    product = Product.new(:name=>name)
    if product.save
      [201, product.extend(ProductRepresenter).to_json]
    else
      [500, {:message=>"Failed to save product"}.to_json]
    end
  end
end