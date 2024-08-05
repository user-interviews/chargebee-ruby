require 'rest_client'
require 'json'
require 'zlib'

module ChargeBee
  module Rest
    def self.request(method, url, env, params=nil, headers={})
      raise Error.new('No environment configured.') unless env
      api_key = env.api_key

      if(ChargeBee.verify_ca_certs?)
        ssl_opts = {
          :verify_ssl => OpenSSL::SSL::VERIFY_PEER,
          :ssl_ca_file => ChargeBee.ca_cert_path
        }
      else
        ssl_opts = {
          :verify_ssl => false
        }
      end
      case method.to_s.downcase.to_sym
      when :get, :head, :delete
        headers = { :params => params }.merge(headers)
        payload = nil
      else
        payload = params
      end

      user_agent = ChargeBee.user_agent
      headers = {
        "User-Agent" => user_agent,
        :accept => :json,
        "Lang-Version" => RUBY_VERSION,
        "OS-Version" => RUBY_PLATFORM,
        }.merge(headers)
      opts = {
        :method => method,
        :url => env.api_url(url),
        :user => api_key,
        :headers => headers,
        :payload => payload,
        :open_timeout => env.connect_timeout,
        :timeout => env.read_timeout,
        :raw_response => true
        }.merge(ssl_opts)

      begin
        response = RestClient::Request.execute(opts)
      rescue RestClient::ExceptionWithResponse => e
        if rcode = e.http_code
          raise handle_for_error(e, rcode)
        else
          raise IOError.new("IO Exception when trying to connect to chargebee with url #{opts[:url]} . Reason #{e}", e)
        end
      rescue Exception => e
        raise IOError.new("IO Exception when trying to connect to chargebee with url #{opts[:url]} . Reason #{e}", e)
      end

      rheaders = response.headers
      rbody = decode_response_body(response)

      begin
        resp = JSON.parse(rbody)
      rescue Exception => e
        if rbody.include? "503"
          raise Error.new("Sorry, the server is currently unable to handle the request due to a temporary overload or scheduled maintenance. Please retry after sometime. \n type: internal_temporary_error, \n http_status_code: 503, \n error_code: internal_temporary_error,\n content: #{rbody.inspect}", e)
        elsif rbody.include? "504"
          raise Error.new("The server did not receive a timely response from an upstream server, request aborted. If this problem persists, contact us at support@chargebee.com. \n type: gateway_timeout, \n http_status_code: 504, \n error_code: gateway_timeout,\n content:  #{rbody.inspect}", e)
        else
          raise Error.new("Sorry, something went wrong when trying to process the request. If this problem persists, contact us at support@chargebee.com. \n type: internal_error, \n http_status_code: 500, \n error_code: internal_error,\n content:  #{rbody.inspect}", e)
        end
      end
      resp = Util.symbolize_keys(resp)
      return resp, rheaders
    end

    def self.handle_for_error(e, rcode=nil)
      rbody = decode_response_body(e.response) if e.response

      if (rcode == 204)
        raise Error.new("No response returned by the chargebee api. The http status code is #{rcode}")
      end
      begin
        error_obj = JSON.parse(rbody)
        error_obj = Util.symbolize_keys(error_obj)
      rescue Exception => e
        raise Error.new("Error response not in JSON format. The http status code is #{rcode} \n #{rbody.inspect}", e)
      end
      type = error_obj[:type]
      if ("payment" == type)
        raise PaymentError.new(rcode, error_obj)
      elsif ("operation_failed" == type)
        raise OperationFailedError.new(rcode, error_obj)
      elsif ("invalid_request" == type)
        raise InvalidRequestError.new(rcode, error_obj)
      else
        raise APIError.new(rcode, error_obj)
      end
    end

    # rest_client 2.1 dropped support for custom handling of compression. This adds back the ability
    # to gzip and deflate body responses.
    # See https://github.com/rest-client/rest-client/blob/master/history.md#210 for more info
    def self.decode_response_body(response)
      encoding = response.headers[:content_encoding]
      body = response.body

      if (!body) || body.empty?
        body
      elsif encoding == 'gzip'
        Zlib::GzipReader.new(StringIO.new(body)).read
      elsif encoding == 'deflate'
        begin
          Zlib::Inflate.new.inflate body
        rescue Zlib::DataError
          # No luck with Zlib decompression. Let's try with raw deflate,
          # like some broken web servers do.
          Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate body
        end
      else
        body
      end
    end
  end
end