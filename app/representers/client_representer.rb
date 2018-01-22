module ClientRepresenter
  include Roar::JSON::HAL

  property :info
  #property :status_ap
  property :created_at, :writeable=>false

  link :self do
    "/faq/#{id}"
  end
end