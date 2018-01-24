require 'rest-client'
require 'json'
require 'dotenv'
require 'awesome_print'
require_relative 'serialize_service'

Dotenv.load('../../config/variables.env.development')


class SapService

  def initialize

  end

  def server_get(resource)
    RestClient.get "http://#{ENV["AUTH"]}@#{ENV["SERVER_URL"]}" + resource
  end

  def server_post(resource, data)
    RestClient.post "http://#{ENV["AUTH"]}@#{ENV["SERVER_URL"]}" + resource, data
  end

  def self.sap(resource, data = {}.to_json)
    response =  RestClient.post "http://#{ENV["AUTH"]}@#{ENV["SAP_IP_INTERNO_TESTE"]}" + resource, data #, headers = {"charset" => "windows-1252"}
    return JSON.parse(response.body)
  end

  def self.get_cliente_com_foto(id)
    data = {
        :zparam => id,
        :tipo => '0'
    }.to_json
    dados_cliente = {}
    sap("ZRFC_GET_CLIENTECOMFOTO", data).tap do |result|
      raise "Não houve resultados." if result["ZRFC_GET_CLIENTECOMFOTO"]["ZCUSTOMERCLI"].nil?
      titular = result["ZRFC_GET_CLIENTECOMFOTO"]["ZCUSTOMERCLI"].first
      dados_cliente = SerializeService.filter(["LIMCRED", "SALDODISP", "SALDO", "HISTORICO", "APRAZO", "PEDRA", "PREMIO_DISP", "BONUS_VALIDADE", "BONUS_EXPIRANDO", "NAME1", "STCD1", "STCD2", "STCD3", "STKZN", "TITULAR", "DATLT", "OBJ_ATU", "OBJ_IDE"], titular)
      ["OBJ_ATU", "OBJ_IDE"].each do |img|
        if result["ZRFC_GET_CLIENTECOMFOTO"].has_key?(img)
          foto = 'data:image/png;base64, '
          result["ZRFC_GET_CLIENTECOMFOTO"][img].each do |parte|
            foto << parte["LINE"]
          end
          dados_cliente[img] = foto
        else
          dados_cliente[img] = "images/default.png"
        end
      end
    end
    return dados_cliente#.sort.to_h
  end

  def self.get_saldo_vc(id)
    data = {
        :i_cliente => "%010d" % id
    }.to_json
    dados_cliente = {}
    sap("ZGET_SALDO_VC", data).tap do |result|
      dados_cliente["SALDO_VC"] = result["ZGET_SALDO_VC"]["E_SALDO"]
    end
    return dados_cliente
  end

  def self.get_medalhas_cliente(id)
    data = {
        :i_kunnr => "%010d" % id,
        :i_ano => Time.now.strftime('%Y')
    }.to_json
    dados_cliente = {}
    sap("ZMED_CLIENTES", data).tap do |result|
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
    data = {
        :I_CLIENTE => "%010d" % id
    }.to_json
    dados_cliente = {}
    sap("ZRFC_GETCLIENTE_COMUNICACAO", data).tap do |result|
      cliente_comunicacao = result["ZRFC_GETCLIENTE_COMUNICACAO"]
      dados_cliente["EMAIL"] = SerializeService.serialize_email(cliente_comunicacao["EMAILS"])
      dados_cliente["TELEFONES"] = SerializeService.serialize_telefones(cliente_comunicacao["TELEFONES"])
    end
    return dados_cliente
  end

  def self.get_cliente_neurotech(id)
    data = {
        :I_CLIENTE => "%010d" % id
    }.to_json
    dados_cliente = {}
    sap("ZNT_GET_SCORE", data).tap do |result|
      #dados_neurotech = result["ZNT_GET_SCORE"]
      dados_neurotech = SerializeService.filter(["E_LIMITE_VENDEDOR","E_LIMITE_GERENCIA", "E_LIMITE_CADASTRO", "E_SCORE"], result["ZNT_GET_SCORE"])
      #p dados_neurotech
      get_cliente_idf(id).tap do |result|
        dados_cliente = dados_neurotech.merge(result)
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
      dados_cliente["TOTAL_PONTUACAO"] = result["ZRFC_IDFCALCULOVENDAPRAZO"]["TOTAL_PONTUACAO"]
    end
    return dados_cliente
  end

  def self.get_info_pedra_cliente(id)
    data = {
        :I_CODCLI => "%010d" % id,
    }.to_json
    dados_cliente = {}
    sap("ZGETCLI_NIVEL01", data).tap do |result|
      dados_cliente = result
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
#
#p JSON.parse(SapService.get_cliente_json(2410071 ).to_json).to_s.gsub("=>", ":")
#

#p SapService.get_cliente_com_foto(2410071)
#p SapService.get_cliente_com_foto(2410071)
#p SapService.get_cliente_comunicacao(1020010)
#p SapService.get_cliente_neurotech(1020010)
#p SapService.get_cliente_idf(1020010)
p SapService.get_info_cliente_new(1020010)
p SapService.get_info_pedra_cliente(1020010)



