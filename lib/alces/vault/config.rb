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
