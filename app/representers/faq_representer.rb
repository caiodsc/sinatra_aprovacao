module FaqRepresenter
  include Roar::JSON::HAL

  property :question
  #property :status_ap
  property :created_at, :writeable=>false

  link :self do
    "/faq/#{id}"
  end
end