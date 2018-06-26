require 'yaml'
require 'active_support/core_ext/module/delegation'
require 'whirly'

module Alces
  module Vault
    class VaultData
      def initialize
        @data ||= load
      end

      delegate :[]=, :[], :keys, :delete, to: :@data

      def save
        Whirly.start(spinner: 'star',
                     remove_after_stop: true,
                     append_newline: false,
                     status: Paint['Storing vault data', '#2794d8']) do
          obj = vault_bucket.objects.build('vault/vault.dat')
          obj.content = encrypted_data
          obj.save
          obj.copy(key: "vault/vault-backup-#{Time.now.strftime('%Y-%m-%d-%H%M')}.dat")
        end
      end

      def fetch(k)
        keys = k.split('.')
        atom = @data[keys.shift]
        keys.each do |key|
          break if atom.nil?
          raise "Invalid nesting" unless atom.is_a?(Hash)
          atom = atom[key]
        end
        atom
      end

      def set(k, v)
        if k.include?('.')
          keys = k.split('.')
          target = keys.pop
          pk = keys.shift
          parent_atom =
            if @data.key?(pk)
              @data[pk]
            else
              {}.tap do |h|
                @data[pk] = h
              end
            end
          keys.each do |key|
            if parent_atom.nil? || parent_atom.is_a?(Hash)
              parent_atom =
                if parent_atom.key?(key)
                  parent_atom[key]
                else
                  {}.tap do |h|
                    parent_atom[key] = h
                  end
                end
            else
              raise "Invalid nesting"
            end
          end
          if v.nil?
            parent_atom.delete(target)
          else
            if parent_atom.is_a?(Hash)
              parent_atom[target] = v
            else
              raise "Invalid nesting"
            end
          end
        else
          if v.nil?
            self.delete(k)
          else
            self[k] = v
          end
        end
      end

      def all_keys(max_depth = 0, depth = 0, parent = nil, pk = nil)
        keys = []
        if max_depth == 0 || depth < max_depth
          (parent || @data).each do |k,v|
            key = (pk.nil? ? k : [pk, k].join('.'))
            keys << key
            if v.is_a?(Hash)
              keys << all_keys(max_depth, depth + 1, v, key)
            end
          end
        end
        keys.flatten
      end

      private
      def encrypted_data
        # ensure all pubkeys are imported
        Vault.manager.import_keys
        Vault.gpg.encrypt(@data.to_yaml,
                          recipients: Vault.manager.recipients,
                          always_trust: true).read
      end

      def load
        retval = nil
        Whirly.start(spinner: 'star',
                     remove_after_stop: true,
                     append_newline: false,
                     status: Paint['Fetching vault data', '#2794d8']) do
          encrypted_data = vault_file.content
          retval = YAML.load(Vault.gpg.decrypt(encrypted_data).read)
        end
        retval
      rescue GPGME::Error::DecryptFailed, S3::Error::NoSuchKey
        {}
      end

      def vault_file
        vault_bucket.objects.find('vault/vault.dat')
      end

      def vault_bucket
        Vault.s3.bucket('alces')
      end
    end
  end
end
