class Client
  include Mongoid::Document
  include Mongoid::Timestamps
  field :info, type: Hash
  #field :question, type: String
  #field :status_ap, type String
end