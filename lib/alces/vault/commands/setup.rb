require 'tty-prompt'

module Alces
  module Vault
    module Commands
      class Setup
        def setup(args, opts)
          # detect if there's already a key
          if Vault.manager.key
            STDERR.puts "Already has a key"
            puts Vault.manager.key.inspect
            return
          end
          STDERR.puts "No key yet"
          name = prompt.ask('Name:')
          email = prompt.ask('Email address:')
          password = prompt.mask('Password:')
          Vault.manager.generate_key(name, email, password)
          # store pubkey in config file
          Vault.manager.store_key
          puts Vault.config.inspect
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
