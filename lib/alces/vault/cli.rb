require 'commander/no-global-highline'
require 'alces/vault/commands/atoms'
require 'alces/vault/commands/setup'

module Alces
  module Vault
    class CLI
      include Commander::Methods

      def run
        program :name, 'alces vault'
        program :version, '1.1.0'
        program :description, 'Alces Flight vault management'

        command :show do |c|
          c.syntax = 'vault show'
          c.summary = 'Show entries in the Alces Flight vault'
          c.description = 'Show entries in the Alces Flight vault.'
          c.option '--depth DEPTH', Integer
          c.action Commands::Atoms, :show
        end
        alias_command :list, :show

        command :edit do |c|
          c.syntax = 'vault edit <key>'
          c.summary = 'Edit an entry in the Alces Flight vault'
          c.description = 'Edit an entry in the Alces Flight vault.'
          c.action Commands::Atoms, :edit
        end
        alias_command :set, :edit

        command :delete do |c|
          c.syntax = 'vault delete <key>'
          c.summary = 'Delete an entry from the Alces Flight vault'
          c.description = 'Delete an entry from the Alces Flight vault.'
          c.action Commands::Atoms, :delete
        end
        alias_command :rm, :delete

        command :setup do |c|
          c.syntax = 'vault setup'
          c.summary = 'Set up a new vault account/key'
          c.description = 'Set up a new vault account/key.'
          c.action Commands::Setup, :setup
        end

        command :touch do |c|
          c.syntax = 'vault touch'
          c.summary = 'Reencrypt the Alces Flight vault'
          c.description = 'Reencrypt the Alces Flight vault.'
          c.action Commands::Atoms, :touch
        end
        
        run!
      end
    end
  end
end
