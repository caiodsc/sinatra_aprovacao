require 'rest-client'
require 'json'
require 'dotenv'
require 'awesome_print'
require 'date'
require 'active_support/time'
require_relative 'serialize_service'
require 'benchmark'
Dotenv.load('./variables.env.development')

class SapService

  @hoje = Time.now

  def initialize
    super
  end

  def self.server_get(resource)
    response = RestClient.get "http://#{ENV["AUTH_SERVER"]}@#{ENV["SERVER_URL"]}" + resource
    return JSON.parse(response.body)
  end

  def self.server_post(resource, data)
    RestClient.post "http://#{ENV["AUTH"]}@#{ENV["SERVER_URL"]}" + resource, data
  end

  def self.sap(resource, data = {}.to_json)
    #safe_response = {}
    begin
      RestClient.post("http://#{ENV["AUTH"]}@#{ENV["SAP_IP_INTERNO_TESTE"]}" + resource, data).tap do |response|#, headers = {"charset" => "windows-1252"}
        return JSON.parse(response.body)#.merge({"RFC_STATUS"=>response.code})
      end
    rescue => e
      return JSON.parse(e.response.body)#.merge({"RFC_STATUS"=>e.response.code})
    end
  end

  def self.get_cliente_com_foto(id)
    cliente = {}
    sap("ZRFC_GET_CLIENTECOMFOTO", { :zparam => id, :tipo => '0' }.to_json ).tap do |result|
      raise "Não houve resultados." if result["ZRFC_GET_CLIENTECOMFOTO"]["ZCUSTOMERCLI"].nil?

      cliente = result["ZRFC_GET_CLIENTECOMFOTO"]["ZCUSTOMERCLI"].first

      cliente["ATRASADO_CLI"] = result["ZRFC_GET_CLIENTECOMFOTO"]["ATRASADO_CLI"]
      cliente["ATRASADO_DEP"] = result["ZRFC_GET_CLIENTECOMFOTO"]["ATRASADO_DEP"]
      cliente["ATRASADO_AVA"] = result["ZRFC_GET_CLIENTECOMFOTO"]["ATRASADO_AVA"]
      cliente["ATRASADO_DIAS"] = result["ZRFC_GET_CLIENTECOMFOTO"]["ATRASADO_DIAS"]
      cliente["MAIOR_ATRASO"] = result["ZRFC_GET_CLIENTECOMFOTO"]["MAIOR_ATRASO"]
      cliente["LISTABLOQUEIO"] = result["ZRFC_GET_CLIENTECOMFOTO"]["LISTABLOQUEIO"]

      threads = []
      ["OBJ_ATU", "OBJ_IDE", "OBJ_SIG"].each do |img|
        threads << Thread.new{
          next unless result["ZRFC_GET_CLIENTECOMFOTO"].has_key?(img)
          foto = ''
          result["ZRFC_GET_CLIENTECOMFOTO"][img].each do |parte|
            foto << parte["LINE"]
          end
          cliente[img] = foto
        }
      end
      threads.each {|t| t.join}
    end
    return cliente
  end #OK

  def self.get_cliente_endereco(pstlz, regio, numero)
    cliente = {}
    begin
      sap("Z_GET_ENDERECO02N", {:i_logradouro => pstlz}.to_json).tap do |result|
        endereco = result["Z_GET_ENDERECO02N"]["T_LOG_CEP"].first
        cliente["RECEBEDOR_CEP"] = endereco["RECEBEDOR"]

        if (!['AM', 'RO', 'RR', 'AC'].include?(regio) or
            numero.nil?)
          cliente["ATUALIZAR_END"] = 'X'
        end

      end
    rescue Exception
      cliente["ATUALIZAR_END"] = 'X'
    end
    return cliente
  end

  def self.get_cliente_score(id)
    cliente = {}
    begin
      sap("ZNT_GET_SCORE", { :I_CLIENTE => "%010d" % id }.to_json ).tap do |result|
        cliente["NEUROTECH"] = result["ZNT_GET_SCORE"]
      end
    rescue Exception
    end
    return cliente
  end

  def self.get_cliente_comunicacao(id)
    cliente = {}
    sap("ZRFC_GETCLIENTE_COMUNICACAO", { :I_CLIENTE => "%010d" % id }.to_json).tap do |result|
      cliente["TELEFONES"] = result["ZRFC_GETCLIENTE_COMUNICACAO"]["TELEFONES"]
      cliente["EMAILS"] = result["ZRFC_GETCLIENTE_COMUNICACAO"]["EMAILS"]
    end
    return cliente
  end

  def self.get_cliente_consolidacao(id_titular)
    cliente = {}
    begin
      # Informações de contrato liquidado
      sap("ZIDF_GETCONSOLIDACAO", {:i_kunnr => "%010d" % id_titular}.to_json).tap do |result|
        unless result["ZIDF_GETCONSOLIDACAO"]["CONSOLIDACAO"].empty?
          consolid = result["ZIDF_GETCONSOLIDACAO"]["CONSOLIDACAO"].first
          cliente["COMPRAS_LIQUIDAD"] = consolid["COMPRAS_LIQUIDAD"]
        end
      end
    rescue Exception
    end
    return cliente
  end

  def self.merge_titular_dependente(titular)
    cliente = {}
    sap("ZRFC_GET_CLIENTECOMFOTO", {:zparam => titular,
                                    :tipo => 0}.to_json).tap do |result|
      raise "Não houve resultados." if result["ZRFC_GET_CLIENTECOMFOTO"]["ZCUSTOMERCLI"].nil?

      titular = result["ZRFC_GET_CLIENTECOMFOTO"]["ZCUSTOMERCLI"].first

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
      if cliente["STKZN"].to_i > 1
        threads = []
        ["OBJ_ATU", "OBJ_IDE", "OBJ_SIG"].each do |img|
          threads << Thread.new{
            next unless result["ZRFC_GET_CLIENTECOMFOTO"].has_key?(img)
            foto = ''
            result["ZRFC_GET_CLIENTECOMFOTO"][img].each do |parte|
              foto << parte["LINE"]
            end
            cliente[img] = foto
          }
        end
        threads.each {|t| t.join}
      end
    end
    return cliente
  end #OK

  def self.get_cliente_saldo_vc(id)
    cliente = {}
    sap("ZGET_SALDO_VC", { :i_cliente => "%010d" % id }.to_json).tap do |result|
      cliente["SALDO_VC"] = result["ZGET_SALDO_VC"]["E_SALDO"]
    end
    return cliente
  end

  def self.get_cliente_saldo_pendente(id)
    return server_get("/pvmovel/saldo_pendente/#{id}")
  end

  def self.get_cliente_credito(stcd2)
    response = server_get("/pvmovel/ccredito/#{stcd2}")
    response.delete('online') unless response['CCREDITO'].nil?
    unless response['CCREDITO'].nil?
      return response
    end
    return {}
  end

  def self.get_cliente_idf(id)
    response = server_get("/pvmovel/idfs/#{id}")
    return {"IDFS" => response["ZRFC_IDFCALCULOVENDAPRAZO"]}
  end

  def self.get_cliente_medalhas(id)
    cliente = {}
    begin
      sap("ZMED_CLIENTES", {:i_kunnr => "%010d" % id,
                            :i_ano => Time.now.strftime('%Y')}.to_json).tap do |result|
        cliente["MEDALHAS"] = result["ZMED_CLIENTES"]["T_MED_CLIENTES"]
      end
    rescue Exception
    end
    return cliente
  end

  def self.get_info_pedra_cliente(id)
    cliente = {}
    sap("ZGETCLI_NIVEL01", { :I_CODCLI => "%010d" % id }.to_json).tap do |result|
      cliente["PTS_PX_PEDRA"] = result["ZGETCLI_NIVEL01"]["E_QTD_PROX_NIVEL"] unless result["ZGETCLI_NIVEL01"].nil?
    end
    return cliente
  end

  def self.get_cliente_json(id)
    tipo ||= 0
    tipo = case tipo
             when 'cpf'
               1
             when 'cnpj'
               2
             else
               tipo
           end
    pesquisa ||= 0
    threads = []
    cliente = SapService.get_cliente_com_foto(id)
    pstlz = cliente["PSTLZ"]
    kunnr = cliente["KUNNR"].to_i
    stcd2 = cliente["STCD2"]
    titular = cliente["TITULAR"].to_i
    regio = cliente["REGIO"]
    numero = cliente["NUMERO"]
    id_titular = (cliente["TITULAR"].to_i > 0) ? cliente["TITULAR"].to_i : kunnr
    if titular > 0 and pesquisa == 0
      threads << Thread.new {SapService.merge_titular_dependente(titular)}
    end
    if pesquisa.to_i == 0
      threads << Thread.new {SapService.get_cliente_endereco(pstlz, regio, numero)}
      unless (id_titular.to_i >= 900000) and (id_titular.to_i <= 999999)
        threads << Thread.new {SapService.get_cliente_saldo_pendente(kunnr)}
        unless stcd2.nil? or stcd2.empty?
          threads << Thread.new {SapService.get_cliente_credito(stcd2.to_i)}
        end
        threads << Thread.new {SapService.get_cliente_consolidacao(id_titular.to_i)}
        threads << Thread.new {SapService.get_info_pedra_cliente(kunnr)}
        threads << Thread.new {SapService.get_cliente_comunicacao(kunnr)}
        threads << Thread.new {SapService.get_cliente_score(kunnr)}
        threads << Thread.new {SapService.get_cliente_medalhas(kunnr)}
        threads << Thread.new {SapService.get_cliente_idf(kunnr)}
        threads << Thread.new {SapService.get_cliente_saldo_vc(kunnr)}
      end
    end
    threads.each do |thr|
      thr.join
      cliente = cliente.merge(thr.value)
    end
    if pesquisa.to_i == 0 and not ((id_titular.to_i >= 900000) and (id_titular.to_i <= 999999))
      cliente.delete('online')
    end
    cliente["PEDRA"] = cliente["PEDRA"].sub( "+", " PLUS" )
    if pesquisa.to_i > 0
      cliente["SALDO_PENDENTE"] = 0
      cliente["SALDO_A_COMPENSAR"] = 0
      cliente["COMPRAS_LIQUIDAD"] = 0
      cliente["PTS_PX_PEDRA"] = 0
      cliente["TELEFONES"] = nil
      cliente["EMAILS"] = nil
      cliente["MEDALHAS"] = nil
      cliente["SALDO_VC"] = 0

      cliente[:IDFS] = {"BLOQUEIO" => '',
                        "CHEQUE_DEVOLVIDO" => '',
                        "CLIENTE_ESPECIAL" => '',
                        "CLIENTE_TITULAR" => '',
                        "COMPRAS_ABERTAS" => 0,
                        "COMPRAS_LIQUIDADAS" => 0,
                        "CONTRATOS_ATRASADOS" => 0,
                        "CONTRATOS_MAIOR_ATRASO" => 0,
                        "FATURA_ATRASADA" => '',
                        "FATURA_PCI" => '',
                        "FUNCIONARIO" => '',
                        "NIVEL_CREDITO" => '',
                        "OBS_IDFS" => '',
                        "POSSUI_REPAC_FATURA" => '',
                        "PRESTACOES_MES" => 0,
                        "RENDA_FAMILIAR" => 0,
                        "SALDO_DEVEDOR_TOTAL" => 0,
                        "SALDO_DISPONIVEL" => 0,
                        "TOTAL_PONTUACAO" => 0,
                        "CALCULO" => []}
    end

    return {
        "clientes" => cliente,
        "online" => "S"
    }
  end

end

puts Benchmark.measure {
  SapService.get_cliente_json(1239220)
}.real



#p SapService.get_cliente_credito(2410070)