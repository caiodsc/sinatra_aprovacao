require 'rest-client'
require 'json'
require 'dotenv'
require "awesome_print"
Dotenv.load('../../config/variables.env.development')


class SapService

  def initialize
    # Resources
    #Dotenv.load('./config/variables.env.development')
    #ENV["API_URL"] = "http://180.200.1.231:4567/"
    #ENV["AUTH"] = "bemolPVM pvm2012"
    @bancohoras = 'ZHR_CONSBANCOHORAS_INTRANET'
    @certificado = ''
    @contracheque = ''
    @descontos = 'Z_GET_DESC_INFO14'
    @avaliacaofuncional = 'ZHR_CONSAVALFUNC2_INTRANET'
    @emailmatricula = 'ZBOT_EMAIL_MATRICULA'
    @espelhocrediario = 'ZGET_ESPELHOCREDIARIO'
  end

  def server_get(resource)
    RestClient.get "http://#{ENV["AUTH"]}@#{ENV["SERVER_URL"]}" + resource
  end

  def server_post(resource, data)
    RestClient.post "http://#{ENV["AUTH"]}@#{ENV["SERVER_URL"]}" + resource, data
  end

  def self.sap(resource, data = {}.to_json)
    RestClient.post "http://#{ENV["AUTH"]}@#{ENV["SAP_URL"]}" + resource, data
  end

  def self.get_client_with_photo(id)
    data = {
        :zparam => id,
        :tipo => '0'
    }.to_json
    cliente = {}
    sap("ZRFC_GET_CLIENTECOMFOTO", data).tap do |response|
      result = JSON.parse(response.body)
      raise "Não houve resultados." if result["ZRFC_GET_CLIENTECOMFOTO"]["ZCUSTOMERCLI"].nil?

      titular = result["ZRFC_GET_CLIENTECOMFOTO"]["ZCUSTOMERCLI"].first
      cliente["TITULAR"] = titular

      ["ATRASADO_CLI", "ATRASADO_DEP", "ATRASADO_AVA", "ATRASADO_DIAS", "MAIOR_ATRASO"].each do |k|
        cliente[k] = result["ZRFC_GET_CLIENTECOMFOTO"][k]
      end
      # e bloqueios???
      ["LIMCRED", "NIVELCRED", "STRAS", "ORT02", "LAND1", "LZONE", "REGIO", "PSTLZ", "SALDODISP",
       "SALDO", "HISTORICO", "KATR6", "AVISTA", "APRAZO", "LOGRADOURO", "NUMERO", "COMPLEMENTO",
       "COMPLEMENTO_2", "PEDRA", "PREMIO_DISP", "PREMIO", "BONUS_VALIDADE", "BONUS_EXPIRANDO"].each do |k|
        cliente[k] = titular[k]
      end

      # Foto do titular (PJ dependente)
      if true
        ["OBJ_ATU", "OBJ_IDE", "OBJ_SIG"].each do |img|
          next unless result["ZRFC_GET_CLIENTECOMFOTO"].has_key?(img)
          foto = ''
          result["ZRFC_GET_CLIENTECOMFOTO"][img].each do |parte|
            foto << parte["LINE"]
          end
          cliente[img] = foto
        end
      end
    end
    return cliente
  end

  def self.get_saldo_vc(id)
    data = {
        :i_cliente => "%010d" % id
    }.to_json
    cliente = {}
    sap("ZGET_SALDO_VC", data).tap do |response|
      result = JSON.parse(response.body)
      cliente["SALDO_VC"] = result["ZGET_SALDO_VC"]["E_SALDO"]
    end
    return cliente
  end

  def self.get_medalhas_cliente(id)
    data = {
        :i_kunnr => "%010d" % id,
        :i_ano => Time.now.strftime('%Y')
    }.to_json
    cliente = {}
    sap("ZMED_CLIENTES", data).tap do |response|
      result = JSON.parse(response.body)
      cliente["MEDALHAS"] = result["ZMED_CLIENTES"]["T_MED_CLIENTES"]
    end
    return cliente
  end

  def self.get_info_pedra_cliente(id)
    cliente = get_client_with_photo(id)
    info_pedra = nil
    sap("ZNIVEL_CLIENTE").tap do |response|
      result = JSON.parse(response.body)
      cliente["PTS_PX_PEDRA"] = if ['DIAMANTE', 'DIAMANTE+', ''].include?(cliente["PEDRA"])
                                  info_pedra = 0
                                else
                                  pedra = result["ZNIVEL_CLIENTE"]["T_NIVEL_CLI"]
                                  i_pedra = pedra.index {|p| p["DESCRICAO_NIVEL"] == cliente["PEDRA"]}
                                  min_pts = pedra[i_pedra+1]["PONTOS_MINIMOS"]
                                  info_pedra = [min_pts.to_i - cliente["HISTORICO"].to_i ,0].max
                                end
    end
    return info_pedra
  end

  def self.get_info_cliente_new(id)
    data = {
        :I_CODCLI => "%010d" % id,
    }.to_json
    dados_cliente = nil
    sap("ZGETCLI_NIVEL01", data).tap do |response|
      dados_cliente = JSON.parse(response.body)
    end
    return dados_cliente
  end

  def self.get_cliente_json(id)
    cliente = {}
    cliente["CLIENTE_COM_FOTO"] = get_client_with_photo(id)
    cliente["SALDO_VC"] = get_saldo_vc(id)
    cliente["MEDALHAS_CLIENTE"] = get_medalhas_cliente(id)
    cliente["PTS_PROX_NIVEL"] = get_info_pedra_cliente(id)
    cliente["INFO_PEDRA"] = get_info_cliente_new(id)
    return cliente
  end

end


cliente = {}
#c = s.sap_get('pvmovel/clientes/1020010')
#d = s.sap("ZRFC_GET_CLIENTECOMFOTO", {:zparam => "1020010", :tipo => '0'}.to_json)
#d = s.sap("ZGET_SALDO_VC", {:i_cliente => "%010d" % 1020010}.to_json)
#d = s.sap("ZMED_CLIENTES", {:i_kunnr => "%010d" % 1020010, :i_ano => Time.now.strftime('%Y')}.to_json)
#d = s.sap("ZMED_CLIENTES", {:i_kunnr => "%010d" % 1020010, :i_ano => Time.now.strftime('%Y')}.to_json)
#p JSON.parse(d)
#r = SapService.get_client_with_photo
#p r
#p SapService.get_info_pedra_cliente(r)
#
#p JSON.parse(SapService.get_cliente_json(2410071 ).to_json).to_s.gsub("=>", ":")
#

p SapService.get_medalhas_cliente(1020010)


