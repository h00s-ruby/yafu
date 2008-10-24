require 'yaml'
require 'digest/md5'
require 'rexml/document'
require 'net/http'

module Flickr

	CONF_FILE = ENV['HOME'] + '/.flickr-upload'

	class Auth
		
		attr_reader :authenticated
		
		def initialize
			load_configuration
		end
		
		def load_configuration
			begin
				@configuration = YAML.load_file(CONF_FILE)
				if @configuration['auth_token'] == ''
					@authenticated = false
				else
					@authenticated = true
				end
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
				login_link = Flickr::response_ok
				request = Hash.new
				request['api_key'] = @configuration['api_key']
				request['frob'] = frob['frob']
				request['perms'] = 'delete'
				request['api_sig'] = generate_signature(request)
				link = 'http://flickr.com/services/auth/?'
				link += 'api_key=' + request['api_key'] + '&'
				link += 'perms=' + 'delete' + '&'
				link += 'frob=' + request['frob'] + '&'
				link += 'api_sig=' + request['api_sig']
				login_link['link'] = link
				return login_link
			else
				return frob
			end
		end
		
		def get_token
			request = Hash.new
			request['method'] = 'flickr.auth.getToken'
			request['api_key'] = @configuration['api_key']
			request['frob'] = @configuration['frob']
			request['api_sig'] = generate_signature(request)
			response = REXML::Document.new(Flickr::http_request(request))
			if response.elements['rsp'].attributes['stat'] == "ok"
				token = Flickr::response_ok
				token['token'] = response.elements['rsp/auth/token'].text
				token['perms'] = response.elements['rsp/auth/perms'].text
				token['nsid'] = response.elements['rsp/auth/user'].attributes['nsid']
				token['username'] = response.elements['rsp/auth/user'].attributes['username']
				token['fullname'] = response.elements['rsp/auth/user'].attributes['fullname']
				@configuration['auth_token'] = token['token']
				save_configuration
				return token
			else
				return Flickr::response_fail(response)
			end			
		end

		private
		def get_frob
			request = Hash.new
			request['method'] = 'flickr.auth.getFrob'
			request['api_key'] = @configuration['api_key']
			request['api_sig'] = generate_signature(request)
			response = REXML::Document.new(Flickr::http_request(request))
			if response.elements['rsp'].attributes['stat'] == "ok"
				frob = Flickr::response_ok
				frob['frob'] = response.elements['rsp/frob'].text
				@configuration['frob'] = frob['frob']
				save_configuration
				return frob
			else
				return Flickr::response_fail(response)
			end
		end

		def generate_signature(request)
			signature = @configuration['secret']
			sorted_request = request.sort
			sorted_request.each do |value|
				signature += value[0] + value[1]
			end
			return Digest::MD5.hexdigest(signature)
		end

	end ##### end Auth class

	def self.response_ok()
		return {'status' => 'ok'}
	end

	def self.response_fail(response)
		return {'status' => 'fail', 'error-code' => response.elements['rsp/err'].attributes['code'], 'message' => response.elements['rsp/err'].attributes['msg']}
	end

	def self.http_request(parameters, url = 'http://api.flickr.com/services/rest/')
		response = Net::HTTP.post_form(URI.parse(url), parameters)
		return response.body
	end
	
end
