require 'flickr'

class Yafu

	def initialize
		@flickr = Flickr.new
	end
	
	def check_configuration
		configuration_changed = false
		
		if @flickr.configuration['api_key'].empty?
			get_api_key
			configuration_changed = true
		end
		
		if @flickr.configuration['secret'].empty?
			get_secret
			configuration_changed = true
		end
		
		if configuration_changed
			@flickr.save_configuration
			puts "Configuration saved to:\n#{@flickr.get_configuration_path}"		
		end
		
		if @flickr.configuration['auth_token'].empty?
			get_auth_token
			configuration_changed = true
		end
		
		if configuration_changed
			@flickr.save_configuration
		end
	end

	def get_api_key
		puts 'Application key not found!'
		puts 'You can get one at: http://www.flickr.com/services/api/keys/apply/'
		print 'Enter your API Key: '
		api_key = gets.chomp
		@flickr.configuration['api_key'] = api_key
	end

	def get_secret
		puts 'API secret key not found!'
		print 'Enter your API secret key: '
		secret = gets.chomp
		@flickr.configuration['secret'] = secret
	end

	def get_auth_token
		puts "In order to use this application for Flickr uplading, you need to authorize it with Flickr."
		puts "Enter following link in your web browser to authorize application on Flickr:"
		puts @flickr.create_login_link['link']
		puts
		puts "When completed, press enter to continue..."
		gets
		token = @flickr.get_token
		if token['status'] == 'ok'
			puts "Application authorized"
		end
	end
	
	def upload(photo)
		if photo.class.to_s == 'String'
			photo = [photo]
			ARGV.clear
			puts 'Enter photo information'
			print 'Title: '
			photo.push(gets.chomp)
			print 'Description: '
			photo.push(gets.chomp)
			print 'Tags: '
			photo.push(gets.chomp)
		end
		puts 'Uploading...'
		response = @flickr.upload(*photo)

		if response['status'] == 'ok'
			puts 'Upload succesful'
		else
			puts "Upload failed: #{response['message']}"
		end
	end

end

yafu = Yafu.new

if ARGV.length == 1
	yafu.check_configuration
	yafu.upload(ARGV[0])
elsif ARGV.length > 1
	ARGV.delete('--no-input')
	yafu.check_configuration
	yafu.upload(ARGV)
else	
	puts 'Usage: yafu file-name'
end
