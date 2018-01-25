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
    safe_response = JSON.parse(response.body).merge({"RFC_STATUS"=>response.code})
    end
    rescue => e
      safe_response = JSON.parse(e.response.body).merge({"RFC_STATUS"=>e.response.code})
    end
    return safe_response
  end

  def self.get_cliente_com_foto(id)
    data = { :zparam => id, :tipo => '0' }.to_json
    dados_cliente = {}
    sap("ZRFC_GET_CLIENTECOMFOTO", data).tap do |result|
      raise "Não houve resultados." if result["ZRFC_GET_CLIENTECOMFOTO"]["ZCUSTOMERCLI"].nil?
      dados_cliente["RFC_STATUS"] = result["RFC_STATUS"]
      return dados_cliente if result["RFC_STATUS"] != 200
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
      dados_cliente["RFC_STATUS"] = result["RFC_STATUS"]
      return dados_cliente if result["RFC_STATUS"] != 200
      dados_cliente["SALDO_VC"] = result["ZGET_SALDO_VC"]["E_SALDO"]
    end
    return dados_cliente
  end
  def self.get_medalhas_cliente(id)
    data = { :i_kunnr => "%010d" % id, :i_ano => Time.now.strftime('%Y') }.to_json
    dados_cliente = {}
    sap("ZMED_CLIENTES", data).tap do |result|
      dados_cliente["RFC_STATUS"] = result["RFC_STATUS"]
      return dados_cliente if result["RFC_STATUS"] != 200
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
      dados_cliente["RFC_STATUS"] = result["RFC_STATUS"]
      return dados_cliente if result["RFC_STATUS"] != 200
      dados_cliente["EMAIL"] = SerializeService.serialize_email(cliente_comunicacao["EMAILS"])
      dados_cliente["TELEFONES"] = SerializeService.serialize_telefones(cliente_comunicacao["TELEFONES"])
    end
    return dados_cliente
  end
  def self.get_info_pedra_cliente(id)
    data = { :I_CODCLI => "%010d" % id }.to_json
    dados_cliente = {}
    sap("ZGETCLI_NIVEL01", data).tap do |result|
      dados_cliente["RFC_STATUS"] = result["RFC_STATUS"]
      return dados_cliente if result["RFC_STATUS"] != 200
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
      dados_cliente["RFC_STATUS"] = result["RFC_STATUS"]
      return dados_cliente if result["RFC_STATUS"] != 200
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
      dados_cliente["RFC_STATUS"] = result["RFC_STATUS"]
      return dados_cliente if result["RFC_STATUS"] != 200
      dados_cliente["TOTAL_PONTUACAO"] = result["ZRFC_IDFCALCULOVENDAPRAZO"]["TOTAL_PONTUACAO"]
    end
    return dados_cliente
  end
  def self.get_contratos_cliente(id)
    data = { :cliente => "%010d" % id }.to_json
    dados_cliente = {}
    sap("Z_GET_CONTRATO_02N", data).tap do |result|
      dados_cliente["RFC_STATUS"] = result["RFC_STATUS"]
      return dados_cliente if result["RFC_STATUS"] != 200
      dados_cliente = dados_cliente.merge(SerializeService.ajusta_contrato(result["Z_GET_CONTRATO_02N"]["T_CONTRATO"].first))
    end
    return dados_cliente
  end
  def self.get_contratos_dependente(id)
    data = { :cliente => "%010d" % id }.to_json
    dados_cliente = {}
    sap("Z_GET_CONTRATO_04", data).tap do |result|
      dados_cliente["RFC_STATUS"] = result["RFC_STATUS"]
      return dados_cliente if result["RFC_STATUS"] != 200
      dados_cliente = dados_cliente.merge(SerializeService.ajusta_contrato(result["Z_GET_CONTRATO_04"]["T_CONTRATO"].first))
    end
    return dados_cliente
  end
  def self.get_contratos_avalista(id)
    data = { :avalista => "%010d" % id }.to_json
    dados_cliente = {}
    sap("Z_GET_CONTRATO_03", data).tap do |result|
      dados_cliente["RFC_STATUS"] = result["RFC_STATUS"]
      return dados_cliente if result["RFC_STATUS"] != 200
      dados_cliente = dados_cliente.merge(SerializeService.ajusta_contrato(result["Z_GET_CONTRATO_03"]["T_CONTRATO"].first))
    end
    return dados_cliente
  end
  def self.get_contratos_liquidados(id)
    data = { :cliente => "%010d" % id }.to_json
    dados_cliente = {}
    sap("Z_GET_CONTRATO_02N", data).tap do |result|
      dados_cliente["RFC_STATUS"] = result["RFC_STATUS"]
      return dados_cliente if result["RFC_STATUS"] != 200
      dados_cliente = dados_cliente.merge(SerializeService.ajusta_contrato(result["Z_GET_CONTRATO_02N"]["T_CONTRATO"].first))
    end
    return dados_cliente
  end
  def self.get_cliente_recebimentos(id)
    data = { :I_CLIENTE => "%010d" % id }.to_json
    dados_cliente = {}
    sap("Z_GET_RECEBIMENTO", data).tap do |result|
      dados_cliente["RFC_STATUS"] = result["RFC_STATUS"]
      return dados_cliente if result["RFC_STATUS"] != 200
      dados_cliente["RECEBIMENTOS"] = result["Z_GET_RECEBIMENTO"]["T_RECFORMAPAG"] || {}
      dados_cliente["RECEBIMENTOS"].delete_if { |r| Date.parse(r["DT_RECEBIMENTO2"]).to_time < (60.days.ago)} unless dados_cliente["RECEBIMENTOS"].empty?
    end
    return dados_cliente
  end
  def self.get_cliente_prestacoes(id)
    data = { :I_CLIENTE => "%010d" % id }.to_json
    dados_cliente = {}
    key_map = {"T_CONTRATOS" => "PRESTACOES", "T_AVALISADOS" => "PRESTACOES_AVA", "T_DEPENDENTES" => "PRESTACOES_DEP"}
    sap("Z_GET_CONTRATO_14N", data).tap do |result|
      dados_cliente["RFC_STATUS"] = result["RFC_STATUS"]
      return dados_cliente if result["RFC_STATUS"] != 200
      ["T_CONTRATOS", "T_AVALISADOS", "T_DEPENDENTES"].each do |prest|
        next unless result["Z_GET_CONTRATO_14N"].has_key?(prest)
        dados_cliente[prest] = SerializeService.ajusta_prestacoes(result["Z_GET_CONTRATO_14N"]["T_CONTRATOS"])
      end
    end
    dados_cliente = SerializeService.map_keys(key_map, dados_cliente)
    dados_cliente = SerializeService.get_comprometimento_from_prestacoes(dados_cliente)
    return dados_cliente
  end
  def self.get_acordo_indenizacao(id)
    data = { :i_cliente => "%010d" % id }.to_json
    dados_cliente = {}
    sap("Z_GET_AC_INDENIZACAO", data).tap do |result|
      dados_cliente["RFC_STATUS"] = result["RFC_STATUS"]
      return dados_cliente if result["RFC_STATUS"] != 200
      dados_cliente["AC_INDENIZACAO"] = result["Z_GET_AC_INDENIZACAO"]["T_ACORDO"].map do |ac|
        ac.select {|k,v| ["IDACORDO", "DATA_ACORDO", "VLRINDENIZACAO"].include?(k)}
      end
    end
    return dados_cliente
  end
  def self.get_cliente_json(id)
    threads = []
    dados_cliente = {}
    dados_cliente["INFO_CONTRATOS"] = {}
    threads << Thread.new { dados_cliente["CLIENTE_COM_FOTO"] = get_cliente_com_foto(id) }
    threads << Thread.new { dados_cliente["SALDO_VC"] = get_saldo_vc(id) }
    threads << Thread.new { dados_cliente["MEDALHAS_CLIENTE"] = get_medalhas_cliente(id) }
    threads << Thread.new { dados_cliente["INFO_COMUNICACAO"] = get_cliente_comunicacao(id) }
    threads << Thread.new { dados_cliente["INFO_PEDRA"] = get_info_pedra_cliente(id) }
    threads << Thread.new { dados_cliente["INFO_NEUROTECH"] = get_cliente_neurotech(id) }
    threads << Thread.new { dados_cliente["INFO_IDF"] = get_cliente_idf(id) }
    threads << Thread.new { dados_cliente["INFO_CONTRATOS"]["CONTRATOS_CLIENTE"] = get_contratos_cliente(id) }
    threads << Thread.new { dados_cliente["INFO_CONTRATOS"]["CONTRATOS_DEPENDENTE"] = get_contratos_dependente(id) }
    threads << Thread.new { dados_cliente["INFO_CONTRATOS"]["CONTRATOS_AVALISTA"] = get_contratos_avalista(id) }
    threads << Thread.new { dados_cliente["INFO_CONTRATOS"]["CONTRATOS_LIQUIDADOS"] = get_contratos_liquidados(id) }
    threads << Thread.new { dados_cliente["INFO_RECEBIMENTOS"] = get_cliente_recebimentos(id) }
    threads << Thread.new { dados_cliente["INFO_PRESTACOES"] = get_cliente_prestacoes(id) }
    threads << Thread.new { dados_cliente["INFO_INDENIZACAO"] = get_acordo_indenizacao(id) }
    threads.each { |thr| thr.join }
    #dados_cliente["CLIENTE_COM_FOTO"] = get_cliente_com_foto(id)
    #dados_cliente["SALDO_VC"] = get_saldo_vc(id)
    #dados_cliente["MEDALHAS_CLIENTE"] = get_medalhas_cliente(id)
    #dados_cliente["INFO_COMUNICACAO"] = get_cliente_comunicacao(id)
    #dados_cliente["INFO_PEDRA"] = get_info_pedra_cliente(id)
    #dados_cliente["INFO_NEUROTECH"] = get_cliente_neurotech(id)
    #dados_cliente["INFO_IDF"] = get_cliente_idf(id)
    #dados_cliente["INFO_CONTRATOS"] = {}
    #dados_cliente["INFO_CONTRATOS"]["CONTRATOS_CLIENTE"] = get_contratos_cliente(id)
    #dados_cliente["INFO_CONTRATOS"]["CONTRATOS_DEPENDENTE"] = get_contratos_dependente(id)
    #dados_cliente["INFO_CONTRATOS"]["CONTRATOS_AVALISTA"] = get_contratos_avalista(id)
    #dados_cliente["INFO_CONTRATOS"]["CONTRATOS_LIQUIDADOS"] = get_contratos_liquidados(id)
    #dados_cliente["INFO_RECEBIMENTOS"] = get_cliente_recebimentos(id)
    #dados_cliente["INFO_PRESTACOES"] = get_cliente_prestacoes(id)
    #dados_cliente["INFO_INDENIZACAO"] = get_acordo_indenizacao(id)
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
#r = Time.now
#p SapService.get_cliente_json(2410071).sort.to_h
#s = Time.now
#p (s-r)