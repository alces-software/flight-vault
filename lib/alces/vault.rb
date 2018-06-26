require 'alces/vault/cli'
require 'alces/vault/vault_data'
require 'alces/vault/manager'
require 'alces/vault/config'

require 'gpgme'
require 's3'

module Alces
  module Vault
    class << self
      def data(&block)
        @data ||= VaultData.new
        if block
          yield(@data)
          @data.save
        else
          @data
        end
      end

      def manager
        @manager ||= Manager.new
      end

      def config
        @config ||= Config.new
      end

      def s3
        @s3 ||= S3::Service
                  .new(
                    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
                  )
      end

      def gpg
        @gpg ||= GPGME::Crypto.new
      end
    end
  end
end

module S3
  class Object
    def bucket_request(*a)
      bucket.send(:bucket_request, *a)
    end
  end
end