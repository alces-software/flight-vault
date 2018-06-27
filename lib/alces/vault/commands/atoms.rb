require 'tty-editor'
require 'whirly'

module Alces
  module Vault
    module Commands
      class Atoms
        def show(args, opts)
          if Process.uid == 0
            prompt.warn "Running as root - you should use your own user!"
          elsif STDOUT.stat.uid == 0
            prompt.warn "Terminal is owned by root (and you aren't root), password entry may fail!"
            prompt.warn "Are you running under `su` or `sudo`? Don't. :)"
          end
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
          if Vault.manager.key.nil?
            prompt.error "No key detected; try 'vault setup'"
            return
          end

          if args.empty?
            prompt.error "This operation requires a key"
            return
          end
          k = args[0]
          Vault.data do |data|
            data.set(k, nil)
          end
          prompt.ok "Atom removed from vault: #{k}"
        rescue GPGME::Error::DecryptFailed
          prompt.error "Access denied; has 'vault touch' been executed by an existing user?"
        end

        def touch(args, opts)
          if Vault.manager.key.nil?
            prompt.error "No key detected; try 'vault setup'"
            return
          end

          Vault.data.save
          prompt.ok "Vault now available to: #{Vault.manager.recipients.join(", ")}"
        rescue GPGME::Error::DecryptFailed
          prompt.error "Access denied; has 'vault touch' been executed by an existing user?"
        end

        def edit(args, opts)
          if Vault.manager.key.nil?
            prompt.error "No key detected; try 'vault setup'"
            return
          end

          if args.empty?
            prompt.error "This operation requires a key"
            return
          end
          k = args[0]
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
                data.set(
                  k,
                  if content[0..3] == "---\n"
                    YAML.load(content) rescue content
                  else
                    content
                  end
                )
              end
            ensure
              file.unlink
            end
          end
          prompt.ok "Atom updated: #{k}"
        rescue GPGME::Error::DecryptFailed
          prompt.error "Access denied; has 'vault touch' been executed by an existing user?"
        rescue TTY::Reader::InputInterrupt
          return
        end

        private
        def prompt
          @prompt ||= TTY::Prompt.new(help_color: :cyan)
        end
      end
    end
  end
end
