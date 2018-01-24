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

  def self.ajusta_contrato(contrato)

    hoje_i = Time.now.strftime('%Y%m%d').to_i
    novo_contrato = filter(["DATA_COMPRA", "CONCEITO", "STATUS", "CONTRATO", "VENCIMENTO"], contrato)

    novo_contrato["VALOR"] = contrato["MONTANTE"]
    novo_contrato["TEXTO"] = case novo_contrato["STATUS"]
                  when 'P'
                    'Pendente'
                  when 'R'
                    'Repactuação'
                  when 'C'
                    'Cancelado'
                  when 'L'
                    'Liquidado'
                  when 'A'
                    if contrato["TITULO_PROTESTADO"] == 'X'
                      'Título em poder do cartório'
                    elsif contrato["SPC"] == 'T'
                      'Tutela antecipada'
                    elsif contrato["PCI"] == 'X'
                      'Em PCI'
                    elsif contrato["VENCIMENTO"].to_i < hoje_i.to_i
                      'Em atraso'
                    else
                      'Em dia'
                    end
                end

    novo_contrato["CONCEITO_TEXTO"] = case novo_contrato["CONCEITO"].to_i
                           when 0
                             'Ótimo'
                           when 1
                             'Bom'
                           when 2
                             'Regular'
                           else
                             'Péssimo'
                         end

    return novo_contrato
  end

  def self.filter(wanted_keys, data)
    filtered_hash = {}
    wanted_keys.each { |key| filtered_hash[key] = data[key] || "" }
    return filtered_hash
  end


end

#data.select { |key, _| wanted_keys.include? key }