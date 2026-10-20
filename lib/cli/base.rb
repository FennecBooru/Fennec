# frozen_string_literal: true

module CLI
  # Base for command groups. Every subclass in lib/cli is picked up by CLI::Runner and becomes a group named after
  # the class, so CLI::Users gives users:create, users:list, etc. Commands are regular Thor commands, and run as the
  # system user
  class Base < Thor
    def self.exit_on_failure?
      true
    end

    def self.group_name
      name.demodulize.underscore
    end

    # shown next to the group in the command list
    def self.summary(text = nil)
      @summary = text if text
      @summary || "#{group_name.humanize} commands"
    end

    def self.banner(command, *)
      "#{File.basename($PROGRAM_NAME)} #{group_name}:#{command.usage}"
    end

    no_commands do
      def invoke_command(*)
        CurrentUser.as_system { super }
      end

      def actor
        User.system
      end

      def fail!(message)
        raise(Thor::Error, message)
      end

      def find_user!(name)
        user = name =~ /\A\d+\z/ ? User.find_by(id: name) : User.find_by_normalized_name(name)
        user || fail!("No user found for #{name}")
      end

      def parse_level!(value)
        level = value =~ /\A\d+\z/ ? value.to_i : User::Levels.name_to_id(value.to_s.tr(" -", "__"))
        return level if User::VALID_LEVELS.include?(level)
        fail!("Unknown level #{value}, use one of: #{User::VALID_LEVELS.sort.map { |l| "#{User::Levels.id_to_name(l).parameterize(separator: '_')} (#{l})" }.join(', ')}")
      end

      # saves the record, failing with its errors
      def save!(record)
        record.save || fail!(record.errors.full_messages.join("; "))
      end

      def print_record(pairs)
        print_table(pairs.map { |key, value| ["#{key}:", value.to_s] })
      end
    end
  end
end
