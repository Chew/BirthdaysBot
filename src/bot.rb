# frozen_string_literal: true

# Gems
require 'discordrb'
require 'ostruct'
require 'yaml'
require 'active_record'
require 'rufus-scheduler'

# Bot configuration
CONFIG = OpenStruct.new YAML.load_file 'data/config.yaml'

puts "Starting bot on Shard ##{ARGV[0]} / #{CONFIG.shards}"

Scheduler = Rufus::Scheduler.new

# ActiveRecord Database
ActiveRecord::Base.establish_connection(
  adapter: 'mysql2', # or 'postgresql' or 'sqlite3' or 'oracle_enhanced'
  host: CONFIG.db['host'],
  database: CONFIG.db['database'],
  username: CONFIG.db['username'],
  password: CONFIG.db['password']
)

# Load non-Discordrb modules and models
Dir['src/modules/*.rb'].each { |mod| load mod }
Dir['src/models/*.rb'].each { |mod| load mod }

Starttime = Time.now

# The main bot module.
module Bot
  # Create the bot.
  # The bot is created as a constant, so that you
  # can access the cache anywhere.
  BOT = Discordrb::Commands::CommandBot.new(client_id: CONFIG.client_id,
                                            token: CONFIG.token,
                                            prefix: CONFIG.prefix,
                                            num_shards: CONFIG.shards,
                                            shard_id: ARGV[0].to_i,
                                            compress_mode: :large)

  # This class method wraps the module lazy-loading process of discordrb command
  # and event modules. Any module name passed to this method will have its child
  # constants iterated over and passed to `Discordrb::Commands::CommandBot#include!`
  # Any module name passed to this method *must*:
  #   - extend Discordrb::EventContainer
  #   - extend Discordrb::Commands::CommandContainer
  # @param klass [Symbol, #to_sym] the name of the module
  # @param path [String] the path underneath `src/modules/` to load files from
  def self.load_modules(klass, path)
    new_module = Module.new
    const_set(klass.to_sym, new_module)
    Dir["src/modules/#{path}/*.rb"].each { |file| load file }
    new_module.constants.each do |mod|
      BOT.include! new_module.const_get(mod)
    end
  end

  load_modules(:DiscordEvents, 'events')
  load_modules(:DiscordCommands, 'commands')

  BOT.command(:reload) do |event|
    break unless event.user.id == CONFIG.owner

    m = event.respond 'Reloading...'

    BOT.clear!

    load_modules(:DiscordEvents, 'events')
    load_modules(:DiscordCommands, 'commands')

    m.edit 'Reloaded! uwu'
  end

  # Run the bot
  BOT.run
end
