# Encoding: utf-8
require 'rubygems'
require 'bundler'

Bundler.require

require 'sinatra'
require 'mongoid'
require 'roar/json/hal'
require 'rack/conneg'
require 'yaml'

require 'dotenv'


Dir["./app/models/*.rb"].each {|file| require file }
Dir["./app/representers/*.rb"].each {|file| require file }



class App < Sinatra::Base

  configure do
    set :views, "./app/views" # Specifying views directory
    set :public_folder, "./app/public"  # specifying stylesheets directory
  end

  get '/' do
    #p @venv["environment"]
    #return "Teste"
    redirect request.base_url + '/home'
  end

  get '/home' do
    p ENV["S3_BUCKET"]
    #"Hello world!"
    erb :home, :layout => :index

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

configure :development, :test do
  Dotenv.load('variables.env.development')
end

configure :production do
  Dotenv.load('variables.env.production')
end

configure do
  Mongoid.load!("config/mongoid.yml", settings.environment)
  set :server, :puma # default to puma for performance
end