class SerializeService

  def initialize

  end

  def self.serialize_email(email)
    if email.nil?
      return ""
    else
      email.each do |email_object|
        if email_object["PRINCIPAL"] == "X"
          return email_object["EMAIL"]
        end
      end
      return email[0]["EMAIL"]
    end
  end

  def self.serialize_telefones(telefones)
    telefones_info = {"PRINCIPAL" => "", "CELULAR" => ""}
    if telefones.nil?
      telefones_info
    else
      telefones.each do |telefone|
        if telefone["PRINCIPAL"] == "X"
          telefones_info["PRINCIPAL"] = telefone["TELEFONE"]
        end
        if telefone["TIPO"] == "CELULAR"
          telefones_info["CELULAR"] = telefone["TELEFONE"]
        end
      end
      return telefones_info
    end
  end

  def self.filter(wanted_keys, data)
    filtered_hash = {}
    wanted_keys.each { |key| filtered_hash[key] = data[key] || "" }
    return filtered_hash
  end


end

#data.select { |key, _| wanted_keys.include? key }