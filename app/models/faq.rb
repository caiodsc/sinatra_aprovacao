class Faq
  include Mongoid::Document
  include Mongoid::Timestamps

  field :question, type: String
  #field :status_ap, type String
end