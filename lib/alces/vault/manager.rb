require 'gpgme'

module Alces
  module Vault
    class Manager
      KEY_PARAMS = <<EOF.freeze
<GnupgKeyParms format="internal">
Key-Type: DSA
Key-Length: 1024
Subkey-Type: ELG-E
Subkey-Length: 1024
Name-Real: %NAME%
Name-Comment: %COMMENT%
Name-Email: %EMAIL%
Expire-Date: 0
Passphrase: %PASSWORD%
</GnupgKeyParms>
EOF

      def key
        GPGME::Key.find(:secret).find do |k|
          k.comment == 'Flight Vault'
        end
      end

      def generate_key(name, email, password)
        vals = {
          'NAME' => name,
          'COMMENT' => 'Flight Vault',
          'EMAIL' => email,
          'PASSWORD' => password
        }
        params = KEY_PARAMS.gsub(/%(.*?)%/) {|m| vals[$1]}
        GPGME::Ctx.new do |ctx|
          ctx.generate_key(params)
        end
      end

      def import_keys
        Vault.config.keys.each do |pubkey|
          GPGME::Key.import(pubkey)
        end
      end

      def store_key
        config = Vault.config
        config.keys << Vault.manager.key.export(armor: true).read
        config.save
      end

      def recipients
        GPGME::Key.find(:public).map do |k|
          k.email
        end
      end
    end
  end
end
