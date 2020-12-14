require "openssl"

module Trailblazer
  class Endpoint::Protocol
    module Controller
      module Cipher # FIXME: copied from Tyrant!
        module_function

        def encrypt_value(ctx, value:, cipher_key:, **)
          cipher = OpenSSL::Cipher.new('DES-EDE3-CBC').encrypt
          cipher.key = Digest::SHA1.hexdigest(cipher_key)[0..23] # ArgumentError: key must be 24 bytes
          s = cipher.update(value) + cipher.final

          ctx[:encrypted_value] = s.unpack('H*')[0].upcase
        end

        def decrypt_value(ctx, encrypted_value:, cipher_key:, **)
          cipher = OpenSSL::Cipher.new('DES-EDE3-CBC').decrypt
          cipher.key = Digest::SHA1.hexdigest(cipher_key)[0..23]
          s = [encrypted_value].pack("H*").unpack("C*").pack("c*")

          ctx[:decrypted_value] = cipher.update(s) + cipher.final
        end
      end # Cipher
    end
  end
end
