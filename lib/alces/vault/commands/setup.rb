require 'tty-prompt'
require 'zxcvbn'

module Alces
  module Vault
    module Commands
      class Setup
        def setup(args, opts)
          if Process.uid == 0
            prompt.error "Running as root - you should use your own user!"
            return
          end
          # detect if there's already a key
          k = Vault.manager.key
          if k
            prompt.warn "Setup not required; key detected."
            puts "[#{k.sha}] #{k.name} (#{k.comment}) <#{k.email}>"
            return
          end
          prompt.warn "No key detected; proceeding with key generation."
          name = prompt.ask(sprintf('%20s','Name:'))
          email = prompt.ask(sprintf('%20s','Email address:'))
          password = prompt.mask(sprintf('%20s','Password:')) do |q|
            q.validate( lambda do |a|
                          a.match(/.{8}/) &&
                            Zxcvbn.test(a, [name, email]).score >= 2
                        end, 'Unacceptable password (must be at least 8 chars and not too weak)')
          end
          confirm = prompt.mask(sprintf('%20s','Confirm password:')) do |q|
            q.validate(->(a){a == password}, 'Confirmation must match password')
          end
          Vault.manager.generate_key(name, email, password)
          # store pubkey in config file
          Vault.manager.store_key
          # success message
          prompt.ok "Key set up completed."
          prompt.ok "Please ask an existing user to run the 'vault touch' command."
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
