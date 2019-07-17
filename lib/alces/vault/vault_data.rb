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
        whirly('Storing vault data') do
          obj = vault_bucket.object('vault/vault.dat')
          obj.upload_stream do |write_stream|
            write_stream << encrypted_data
          end
          save_backups
        end
        Vault.log('save')
      end

      def fetch(k)
        Vault.log('fetch', k)
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
        Vault.log((v.nil? ? 'delete' : 'set'), k)
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
      def whirly(message, &block)
        if $stdout.isatty
          Whirly.start(spinner: 'star',
                       remove_after_stop: true,
                       append_newline: false,
                       status: Paint[message, '#2794d8'],
                       &block)
        else
          block.call
        end
      end


      def encrypted_data
        # ensure all pubkeys are imported
        Vault.manager.import_keys
        Vault.gpg.encrypt(@data.to_yaml,
                          recipients: Vault.manager.recipients,
                          always_trust: true).read
      end

      def load
        Vault.log('load')
        retval = nil
        whirly('Fetching vault data') do
          encrypted_data = vault_file.body
          retval = YAML.load(Vault.gpg.decrypt(encrypted_data).read)
        end
        retval
      rescue Aws::S3::Errors::NoSuchKey
        {}
      end

      def save_backups
        fn = "vault-backup-#{Time.now.strftime('%Y-%m-%d-%H%M')}.dat"
        begin
          Vault.s3.client.copy_object(
            bucket: Vault.config.primary_bucket_name,
            copy_source: "/#{Vault.config.primary_bucket_name}/vault/vault.dat",
            key: "vault/#{fn}"
          )
        rescue
          Vault.log('backup', "Failed: #{$!.message}")
          if $!.is_a?(Aws::S3::Errors::NoSuchBucket)
            puts "warning: could not make backup: #{$!.message}"
          else
            raise
          end
        end
        if Vault.config.mirror_bucket_name != ''
          begin
            Vault.s3.client.copy_object(
              bucket: Vault.config.mirror_bucket_name,
              copy_source: "/#{Vault.config.primary_bucket_name}/vault/vault.dat",
              key: "vault/#{fn}"
            )
          rescue
            Vault.log('mirror', "Failed: #{$!.message}")
            if $!.is_a?(Aws::S3::Errors::NoSuchBucket)
              puts "warning: could not mirror backup: #{$!.message}"
            else
              raise
            end
          end
        end
        if Vault.config.local_backup_path != ''
          begin
            File.open(File.join(Vault.config.local_backup_path, fn), 'w') do |f|
              f.write(encrypted_data)
            end
          rescue
            Vault.log('localsave', "Failed: #{$!.message}")
            if $!.is_a?(Errno::ENOENT)
              puts "warning: could not make local save: #{$!.message}"
            else
              raise
            end
          end
        end
      end

      def vault_file
        vault_bucket.object('vault/vault.dat').get
      end

      def vault_bucket
        Vault.s3.bucket(Vault.config.primary_bucket_name)
      end
    end
  end
end
