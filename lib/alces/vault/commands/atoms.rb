require 'tty-editor'
require 'whirly'

module Alces
  module Vault
    module Commands
      class Atoms
        def show(args, opts)
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
        end

        def delete(args, opts)
          if args.empty?
            prompt.error "This operation requires a key"
            return
          end
          k = args[0]
          Vault.data do |data|
            data.set(k, nil)
          end
          prompt.ok "Atom removed from vault: #{k}"
        end

        def touch(args, opts)
          Vault.data.save
          prompt.ok "Vault now available to: #{Vault.manager.recipients.join(", ")}"
        end

        def edit(args, opts)
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
