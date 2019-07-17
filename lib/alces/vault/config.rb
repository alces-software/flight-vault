require 'yaml'

module Alces
  module Vault
    class Config
      def initialize
        @data = load
      end
      
      def keys
        @data[:keys] ||= []
      end

      def save
        File.write(config_path, @data.to_yaml)
      end

      def log_path
        @data[:log_path] ||= "/var/log/flight-vault.log"
      end

      def lock_file
        @data[:lock_file] ||= "/var/run/lock/flight-vault/lock"
      end

      def primary_bucket_name
        @data[:primary_bucket_name] ||= 'alces-vault'
      end

      def mirror_bucket_name
        @data[:mirror_bucket_name] ||= 'alces-vault-mirror'
      end

      def local_backup_path
        @data[:local_backup_path] ||= '/var/lib/vault'
      end

      private
      def root
        @root ||= File.join(File.dirname(__FILE__),'..','..','..')
      end

      def config_path
        @config_path ||= File.join(root, 'etc', 'config.yml')
      end

      def load
        YAML.load_file(config_path) rescue {}
      end
    end
  end
end
