require 'tty-editor'
require 'whirly'

module Alces
  module Vault
    module Commands
      class Atoms
        def show(args, opts)
          warnings
          if Vault.manager.key.nil?
            prompt.error "No key detected; try 'vault setup'"
            return
          end

          data = Vault.data
          k = args[0]
          if k.nil?
            puts data.all_keys(opts.depth || 1).join("\n")
          else
            atom = data.fetch(k)
            case atom
            when String
              puts atom
            when NilClass
              prompt.warn "Key not found: #{k}"
            else
              puts atom.to_yaml
            end
          end
        rescue GPGME::Error::DecryptFailed
          prompt.error "Access denied; has 'vault touch' been executed by an existing user?"
        end

        def delete(args, opts)
          warnings
          if Vault.manager.key.nil?
            prompt.error "No key detected; try 'vault setup'"
            return
          end

          if args.empty?
            prompt.error "This operation requires a key"
            return
          end
          k = args[0]
          Vault.with_lock do
            Vault.data do |data|
              data.set(k, nil)
            end
          end
          prompt.ok "Atom removed from vault: #{k}"
        rescue LockActiveError
          prompt.error "Vault is currently locked (#{$!.message})"
        rescue GPGME::Error::DecryptFailed
          prompt.error "Access denied; has 'vault touch' been executed by an existing user?"
        end

        def touch(args, opts)
          if Vault.manager.key.nil?
            prompt.error "No key detected; try 'vault setup'"
            return
          end

          Vault.with_lock { Vault.data.save }
          prompt.ok "Vault now available to: #{Vault.manager.recipients.join(", ")}"
        rescue LockActiveError
          prompt.error "Vault is currently locked (#{$!.message})"
        rescue GPGME::Error::DecryptFailed
          prompt.error "Access denied; has 'vault touch' been executed by an existing user?"
        end

        def edit(args, opts)
          warnings
          if Vault.manager.key.nil?
            prompt.error "No key detected; try 'vault setup'"
            return
          end

          if args.empty?
            prompt.error "This operation requires a key"
            return
          end
          k = args[0]
          Vault.with_lock do
            Vault.data do |data|
              file = Tempfile.new('vault')
              begin
                atom = data.fetch(k)
                content = case atom
                          when String
                            atom
                          when NilClass
                            ''
                          else
                            atom.to_yaml
                          end
                if TTY::Editor.open(file.path, content: content)
                  content = File.read(file.path).chomp
                  yaml_content = YAML.load(content) rescue :invalid
                  data.set(
                    k,
                    if content[0..3] == "---\n"
                      if yaml_content == :invalid
                        prompt.error "Invalid YAML:\n\n#{content}\n\nModification not made, please try again."
                        return
                      end
                      yaml_content
                    elsif yaml_content.is_a?(Hash)
                      yaml_content
                    else
                      content
                    end
                  )
                end
              ensure
                file.unlink
              end
            end
          end
          prompt.ok "Atom updated: #{k}"
        rescue LockActiveError
          prompt.error "Vault is currently locked (#{$!.message})"
        rescue GPGME::Error::DecryptFailed
          prompt.error "Access denied; has 'vault touch' been executed by an existing user?"
        rescue TTY::Reader::InputInterrupt
          return
        end

        private
        def prompt
          @prompt ||= TTY::Prompt.new(help_color: :cyan)
        end

        def warnings
          if Process.uid == 0
            prompt.warn "Running as root - you should use your own user!"
          elsif STDOUT.stat.uid == 0
            prompt.warn "Terminal is owned by root (and you aren't root), password entry may fail!"
            prompt.warn "Are you running under `su` or `sudo`? Don't. :)"
          end
        end
      end
    end
  end
end
