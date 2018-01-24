require 'rest-client'
require 'json'
require 'dotenv'
require 'awesome_print'
require 'date'
require 'active_support/time'
require_relative 'serialize_service'

Dotenv.load('../../config/variables.env.development')

class SapService

  @hoje = Time.now

  def initialize
    super
  end

  def server_get(resource)
    RestClient.get "http://#{ENV["AUTH"]}@#{ENV["SERVER_URL"]}" + resource
  end

  def server_post(resource, data)
    RestClient.post "http://#{ENV["AUTH"]}@#{ENV["SERVER_URL"]}" + resource, data
  end

  def self.sap(resource, data = {}.to_json)
    safe_response = {}
    begin
    RestClient.post("http://#{ENV["AUTH"]}@#{ENV["SAP_IP_INTERNO_TESTE"]}" + resource, data).tap do |response|#, headers = {"charset" => "windows-1252"}
    safe_response = JSON.parse(response.body).merge({"STATUS"=>response.code})
    end
    rescue => e
      safe_response = JSON.parse(e.response.body).merge({"STATUS"=>e.response.code})
    end
    return safe_response
  end

  def self.get_cliente_com_foto(id)
    data = { :zparam => id, :tipo => '0' }.to_json
    dados_cliente = {}
    sap("ZRFC_GET_CLIENTECOMFOTO", data).tap do |result|
      raise "Não houve resultados." if result["ZRFC_GET_CLIENTECOMFOTO"]["ZCUSTOMERCLI"].nil?
      dados_cliente["STATUS"] = result["STATUS"]
      dados_cliente = dados_cliente.merge(SerializeService.filter(["LIMCRED", "SALDODISP", "SALDO", "HISTORICO", "APRAZO", "PEDRA", "PREMIO_DISP", "BONUS_VALIDADE", "BONUS_EXPIRANDO", "NAME1", "STCD1", "STCD2", "STCD3", "STKZN", "TITULAR", "DATLT", "OBJ_ATU", "OBJ_IDE"], result["ZRFC_GET_CLIENTECOMFOTO"]["ZCUSTOMERCLI"].first))
      ["OBJ_ATU", "OBJ_IDE"].each do |img|
        if result["ZRFC_GET_CLIENTECOMFOTO"].has_key?(img)
          dados_cliente[img] = SerializeService.serialize_foto(result["ZRFC_GET_CLIENTECOMFOTO"][img])
        else
          dados_cliente[img] = "images/default.png"
        end
      end
    end
    return dados_cliente#.sort.to_h
  end

  def self.get_saldo_vc(id)
    data = { :i_cliente => "%010d" % id }.to_json
    dados_cliente = {}
    sap("ZGET_SALDO_VC", data).tap do |result|
      dados_cliente["STATUS"] = result["STATUS"]
      dados_cliente["SALDO_VC"] = result["ZGET_SALDO_VC"]["E_SALDO"]
    end
    return dados_cliente
  end

  def self.get_medalhas_cliente(id)
    data = { :i_kunnr => "%010d" % id, :i_ano => Time.now.strftime('%Y') }.to_json
    dados_cliente = {}
    sap("ZMED_CLIENTES", data).tap do |result|
      dados_cliente["STATUS"] = result["STATUS"]
      dados_cliente["MEDALHAS"] = result["ZMED_CLIENTES"]["T_MED_CLIENTES"]
      dados_cliente["MEDALHAS"].each do |medalha|
        medalha.each do |k, v|
           medalha[k] = medalha[k].gsub("\u251C\u00AC","ê").gsub("\u252C\u00AC", "ª").gsub("\u251C\u00AE", "é").gsub("\u251C\u00BA\u251C\u00FAo", "ção").gsub("\u251C\u2551", "ú")
        end
      end
    end
    return dados_cliente
  end

  def self.get_cliente_comunicacao(id)
    data = { :I_CLIENTE => "%010d" % id }.to_json
    dados_cliente = {}
    sap("ZRFC_GETCLIENTE_COMUNICACAO", data).tap do |result|
      cliente_comunicacao = result["ZRFC_GETCLIENTE_COMUNICACAO"]
      dados_cliente["STATUS"] = result["STATUS"]
      dados_cliente["EMAIL"] = SerializeService.serialize_email(cliente_comunicacao["EMAILS"])
      dados_cliente["TELEFONES"] = SerializeService.serialize_telefones(cliente_comunicacao["TELEFONES"])
    end
    return dados_cliente
  end

  def self.get_info_pedra_cliente(id)
    data = { :I_CODCLI => "%010d" % id }.to_json
    dados_cliente = {}
    sap("ZGETCLI_NIVEL01", data).tap do |result|
      dados_cliente["STATUS"] = result["STATUS"]
      dados_cliente = dados_cliente.merge(SerializeService.filter(["E_NIVEL_PROX", "E_QTD_PROX_NIVEL"], result["ZGETCLI_NIVEL01"]))
    end
    return dados_cliente
  end

  def self.get_cliente_neurotech(id)
    data = {
        :I_CLIENTE => "%010d" % id
    }.to_json
    dados_cliente = {}
    sap("ZNT_GET_SCORE", data).tap do |result|
      dados_cliente["STATUS"] = result["STATUS"]
      dados_neurotech = SerializeService.filter(["E_LIMITE_VENDEDOR","E_LIMITE_GERENCIA", "E_LIMITE_CADASTRO", "E_SCORE"], result["ZNT_GET_SCORE"])
      get_cliente_idf(id).tap do |result|
        dados_cliente = dados_cliente.merge(dados_neurotech.merge({"CLIENTE_IDF" => result}))
      end
    end
    return dados_cliente
  end

  def self.get_cliente_idf(id)
    data = {
        :I_CLIENTE => "%010d" % id
    }.to_json
    dados_cliente = {}
    sap("ZRFC_IDFCALCULOVENDAPRAZO", data).tap do |result|
      dados_cliente["STATUS"] = result["STATUS"]
      dados_cliente["TOTAL_PONTUACAO"] = result["ZRFC_IDFCALCULOVENDAPRAZO"]["TOTAL_PONTUACAO"]
    end
    return dados_cliente
  end

  def self.get_contratos_cliente(id)
    data = { :cliente => "%010d" % id }.to_json
    dados_cliente = {}
    sap("Z_GET_CONTRATO_02N", data).tap do |result|
      dados_cliente["STATUS"] = result["STATUS"]
      dados_cliente = dados_cliente.merge(SerializeService.ajusta_contrato(result["Z_GET_CONTRATO_02N"]["T_CONTRATO"].first))
    end
    return dados_cliente
  end

  def self.get_contratos_dependente(id)
    data = { :cliente => "%010d" % id }.to_json
    dados_cliente = {}
    sap("Z_GET_CONTRATO_04", data).tap do |result|
      dados_cliente["STATUS"] = result["STATUS"]
      dados_cliente = dados_cliente.merge(SerializeService.ajusta_contrato(result["Z_GET_CONTRATO_04"]["T_CONTRATO"].first))
    end
    return dados_cliente
  end

  def self.get_contratos_avalista(id)
    data = { :avalista => "%010d" % id }.to_json
    dados_cliente = {}
    sap("Z_GET_CONTRATO_03", data).tap do |result|
      dados_cliente["STATUS"] = result["STATUS"]
      dados_cliente = dados_cliente.merge(SerializeService.ajusta_contrato(result["Z_GET_CONTRATO_03"]["T_CONTRATO"].first))
    end
    return dados_cliente
  end

  def self.get_contratos_liquidados(id)
    data = { :cliente => "%010d" % id }.to_json
    dados_cliente = {}
    sap("Z_GET_CONTRATO_02N", data).tap do |result|
      dados_cliente["STATUS"] = result["STATUS"]
      dados_cliente = dados_cliente.merge(SerializeService.ajusta_contrato(result["Z_GET_CONTRATO_02N"]["T_CONTRATO"].first))
    end
    return dados_cliente
  end

  def self.get_cliente_recebimentos(id)
    data = { :I_CLIENTE => "%010d" % id }.to_json
    dados_cliente = {}
    sap("Z_GET_RECEBIMENTO", data).tap do |result|
      dados_cliente["STATUS"] = result["STATUS"]
      dados_cliente["RECEBIMENTOS"] = result["Z_GET_RECEBIMENTO"]["T_RECFORMAPAG"]
      dados_cliente["RECEBIMENTOS"].delete_if { |r| Date.parse(r["DT_RECEBIMENTO2"]).to_time < (60.days.ago)}
    end
    return dados_cliente
  end

  def self.get_cliente_json(id)
    dados_cliente = {}
    dados_cliente["CLIENTE_COM_FOTO"] = get_cliente_com_foto(id)
    dados_cliente["SALDO_VC"] = get_saldo_vc(id)
    dados_cliente["MEDALHAS_CLIENTE"] = get_medalhas_cliente(id)
    dados_cliente["PTS_PROX_NIVEL"] = get_info_pedra_cliente(id)
    dados_cliente["INFO_PEDRA"] = get_info_cliente_new(id)
    return dados_cliente
  end

end




#c = s.sap_get('pvmovel/clientes/1020010')
#d = s.sap("ZRFC_GET_CLIENTECOMFOTO", {:zparam => "1020010", :tipo => '0'}.to_json)
#d = s.sap("ZGET_SALDO_VC", {:i_cliente => "%010d" % 1020010}.to_json)
#d = s.sap("ZMED_CLIENTES", {:i_kunnr => "%010d" % 1020010, :i_ano => Time.now.strftime('%Y')}.to_json)
#d = s.sap("ZMED_CLIENTES", {:i_kunnr => "%010d" % 1020010, :i_ano => Time.now.strftime('%Y')}.to_json)
#p JSON.parse(d)
#r = SapService.get_cliente_com_foto
#p r
#p SapService.get_info_pedra_cliente(r)
#p JSON.parse(SapService.get_cliente_json(2410071 ).to_json).to_s.gsub("=>", ":")
#p SapService.get_cliente_com_foto(2410071)
#p SapService.get_cliente_com_foto(2410071)
#p SapService.get_cliente_comunicacao(1020010)
#p SapService.get_cliente_neurotech(1020010)
#p SapService.get_contratos_dependente(1239220)
#p SapService.get_contratos_cliente(2410071)
#p SapService.get_contratos_dependente(2410071)
#SapService.get_contratos_dependente(1239220)
#SapService.get_contratos_dependente(2410071)
p SapService.get_cliente_recebimentos(2410071)