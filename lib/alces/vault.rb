require 'alces/vault/cli'
require 'alces/vault/vault_data'
require 'alces/vault/manager'
require 'alces/vault/config'

require 'gpgme'
require 's3'
require 'logger'
require 'etc'

module Alces
  module Vault
    LockActiveError = Class.new(RuntimeError)

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

      def with_lock(&block)
        lock_file = config.lock_file
        if File.exist?(lock_file)
          raise LockActiveError, File.read(lock_file).chomp
        else
          begin
            File.open(lock_file,'w') do |f|
              f.puts "#{uname} - #{$$}"
            end
            block.call
          ensure
            File.unlink(lock_file)
          end
        end
      end

      def manager
        @manager ||= Manager.new
      end

      def config
        @config ||= Config.new
      end

      def log(op, *params)
        msg = "#{uname} - #{op}".tap do |s|
          if params.any?
            s << " - #{params.join(' ')}"
          end
        end
        logger.info(msg)
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

      private
      def logger
        @logger ||= Logger.new(config.log_path)
      end

      def uname
        @uname ||= Etc.getlogin
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
