require 'yaml'
require 'digest/md5'
require 'rexml/document'
require 'net/http'

CONF_FILE = ENV['HOME'] + '/.yafu'
FLICKR_API_URL = 'http://api.flickr.com/services/rest/'

class Flickr

	attr_reader :configuration
	
	def initialize
		load_configuration
	end

	def load_configuration
		begin
			@configuration = YAML.load_file(CONF_FILE)
		rescue IOError
			@configuration = {'api_key' => '', 'secret' => '', 'frob' => '', 'auth-token' => ''}
			save_configuration
		end
	end
	
	def save_configuration
		File.open(CONF_FILE, 'w') do |out|
			YAML.dump(@configuration, out)
		end
	end
	
	def create_login_link
		frob = get_frob
		if frob['status'] == 'ok'
			login_link = response_ok
			request = {'frob' => frob['frob'], 'perms' => 'write'}
			request['api_key'] = @configuration['api_key']
			request['api_sig'] = generate_signature(request)
			link = "http://flickr.com/services/auth/?api_key=#{@configuration['api_key']}&perms=#{request['perms']}&frob=#{request['frob']}&api_sig=#{request['api_sig']}"
			login_link['link'] = link
			return login_link
		else
			return frob
		end
	end
	
	def get_token
		request = {'frob' => @configuration['frob']}
		response = get_response('flickr.auth.getToken', request)
		begin
			if response.elements['rsp'].attributes['stat'] == 'ok'
				token = response_ok
				parse_token_response(response, token)
				@configuration['auth_token'] = token['token']
				save_configuration
				return token
			end
		rescue
			return response_fail(response)
		end			
	end
	
	def check_token
		return response_other_fail('1002', 'Missing auth token') if @configuration['auth_token'] == ''
		request = {'auth_token' => @configuration['auth_token']}
		response = get_response('flickr.auth.checkToken', request)
		begin
			if response.elements['rsp'].attributes['stat'] == 'ok'
				token = response_ok
				parse_token_response(response, token)
				return token
			end
		rescue
			return response_fail(response)
		end
	end
	
	def get_frob
		request = {}
		response = get_response('flickr.auth.getFrob', request)
		begin
			if response.elements['rsp'].attributes['stat'] == "ok"
				frob = response_ok
				frob['frob'] = response.elements['rsp/frob'].text
				@configuration['frob'] = frob['frob']
				save_configuration
				return frob
			end
		rescue
			return response_fail(response)
		end
	end
	
	def upload(file, title = '', description = '', tags = '', is_public = '', is_friend = '', is_family = '', safety_level = '', content_type = '', hidden = '')
		request = {'api_key' => @configuration['api_key'], 'auth_token' => @configuration['auth_token']}
		request['title'] = title if title != ''
		request['description'] = description if description != ''
		request['tags'] = tags if tags != ''
		request['is_public'] = is_public if is_public != ''
		request['is_friend'] = is_friend if is_friend != ''
		request['is_family'] = is_family if is_family != ''
		request['safety_level'] = safety_level if safety_level != ''
		request['content_type'] = content_type if content_type != ''
		request['hidden'] = hidden if hidden != ''
		
		request['api_sig'] = generate_signature(request)
		
		header, data = create_multipart_post_query(file, request)
		http = Net::HTTP.new('api.flickr.com', 'www')
		http.post('/services/upload/', data, header)
	end
	
	def create_multipart_post_query(file, request)
		boundary = '------------------------AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPp'
		header = {'Content-Type' => 'multipart/form-data; boundary=' + boundary }
		data = "--" + boundary + "\r\n"
		sorted_request = request.sort
		sorted_request.each do |value|
			data += 'Content-Disposition: form-data; name="' + value[0] + '"' + "\r\n\r\n"
			data += value[1] + "\r\n"
			data += "--" + boundary + "\r\n"
		end
		data += 'Content-Disposition: form-data; name="photo"; filename="' + file + '"' + "\r\n"
		data += 'Content-Type: image/jpeg' + "\r\n\r\n"
		data += IO.readlines(file).to_s + "\r\n"
		data += "--" + boundary + "--\r\n"
		return header, data
	end
	
	private
	def response_ok()
		return {'status' => 'ok'}
	end

	def response_fail(response)
		return {'status' => 'fail', 'error-code' => response.elements['rsp/err'].attributes['code'], 'message' => response.elements['rsp/err'].attributes['msg']}
	end

	def response_other_fail(response)
		return {'status' => 'fail'}.merge(response)
	end

	def response_other_fail(error_code, message)
		return {'status' => 'fail'}.merge({'error-code' => error_code, 'message' => message})
	end

	def get_response(method, request, url = FLICKR_API_URL)
		return response_other_fail('1001', 'Missing api key and/or secret') if configuration['api_key'] == '' or configuration['secret'] == ''
		begin
			request['api_key'] = @configuration['api_key']
			request['method'] = method
			request['api_sig'] = generate_signature(request)
			response = REXML::Document.new(Net::HTTP.post_form(URI.parse(url), request).body)
			return response
		rescue
			return response_other_fail('1000', 'Problem with getting response from Flickr service')
		end
	end

	def generate_signature(request)
		signature = configuration['secret']
		sorted_request = request.sort
		sorted_request.each do |value|
			signature += value[0] + value[1]
		end
		return Digest::MD5.hexdigest(signature)
	end

	def parse_token_response(response, token)
		token['token'] = response.elements['rsp/auth/token'].text
		token['perms'] = response.elements['rsp/auth/perms'].text
		token['nsid'] = response.elements['rsp/auth/user'].attributes['nsid']
		token['username'] = response.elements['rsp/auth/user'].attributes['username']
		token['fullname'] = response.elements['rsp/auth/user'].attributes['fullname']
	end

end
