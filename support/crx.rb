#!/usr/bin/env ruby
#target.crx target.pem dir...

#based on crxmake under MIT License.
#https://github.com/Constellation/crxmake

require 'rubygems'
#require 'zipruby'
require 'zip'
require 'openssl'
require 'digest/sha1'
require 'find'
require 'pathname'

begin
	require 'openssl_pkcs8'
	class OpenSSL::PKey::RSA
		alias_method :to_pem, :to_pem_pkcs8
	end
rescue LoadError
	$pkcs8_warning=1
end

# thx masover
MAGIC = 'Cr24'

# CERT_PUBLIC_KEY_INFO struct
KEY = %w(30 81 9F 30 0D 06 09 2A 86 48 86 F7 0D 01 01 01 05 00 03 81 8D 00).map{|s| s.hex}.pack('C*')
KEY_SIZE = 1024

def get_relative base, target
	Pathname.new(target.to_s).relative_path_from(Pathname.new(base.to_s)).to_s
end

def run(argv)
	crx=argv.shift
	pkey=argv.shift
	key=''
	begin
		File.open(pkey,'rb'){|f|
			key=OpenSSL::PKey::RSA.new(f)
		}
	rescue
		if defined?($pkcs8_warning)
			$stderr.puts 'Warn: generated pem must be converted into PKCS8 in order to upload to Chrome WebStore.'
			$stderr.puts 'To suppress this message, do: gem install openssl_pkcs8'
		end
		key=OpenSSL::PKey::RSA.generate(KEY_SIZE)
		File.open(pkey,'wb'){|f|
			f<<key.to_pem
		}
	end

=begin
	zip_buffer = ''
	Zip::Archive.open_buffer(zip_buffer, Zip::CREATE, Zip::BEST_COMPRESSION){|zipb|
		argv.each{|e|
			Find.find(e){|path|
				if path != e && !File.directory?(path)
					name=get_relative(e, path)
					File.open(path,'rb'){|f|
						zipb.add_buffer(name, f.read)
					}
				end
			}
		}
	}
=end
#=begin
	zip_buffer = (Zip::OutputStream.write_buffer{|zipb|
		argv.each{|e|
			Find.find(e){|path|
				if path != e && !File.directory?(path)
					name=get_relative(e, path)
					File.open(path,'rb'){|f|
						zipb.put_next_entry(name,nil,nil,Zip::Entry::DEFLATED,Zlib::BEST_COMPRESSION)
						zipb.write(f.read)
					}
				end
			}
		}
	}).string
#=end
	sig=key.sign(OpenSSL::Digest::SHA1.new,zip_buffer)

	key = key.public_key.to_der
	if key.index(KEY)!=0 then key=KEY+key end #ruby 1.8 wrap
	File.open(crx,'wb'){|f|
		f << MAGIC
		f << [2].pack('V')
		f << [key.size].pack('V')
		f << [sig.size].pack('V')
		f << key
		f << sig
		f << zip_buffer
	}
end

run(ARGV) if __FILE__==$0
