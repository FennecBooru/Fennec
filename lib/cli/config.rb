# frozen_string_literal: true

module CLI
  class Config < Base
    summary("View and change the admin config")

    desc("list", "List every option and its value")
    option(:filter, desc: "Only options containing this")
    def list
      columns = AdminConfig.columns.reject { |c| %w[id updated_at].include?(c.name) }
      columns = columns.select { |c| c.name.include?(options[:filter]) } if options[:filter]
      print_table(columns.map { |c| [c.name, AdminConfig.instance.public_send(c.name).inspect] })
    end

    desc("get NAME", "Show an option's value")
    def get(name)
      say(AdminConfig.instance.public_send(column!(name).name).inspect)
    end

    desc("set NAME VALUE", "Change an option")
    def set(name, value)
      column = column!(name)
      fail!("#{name} is set through #{AdminConfig.env_override_name(name)}") if AdminConfig.env_override?(name)
      fail!("#{name} can't be changed") unless AdminConfig.settable_columns(actor).include?(column)
      config = AdminConfig.uncached
      config.update_with(actor, column.name => cast(column, value))
      fail!(config.errors.full_messages.join("; ")) if config.errors.any?
      say("#{column.name} = #{config.public_send(column.name).inspect}")
    end

    no_commands do
      def column!(name)
        AdminConfig.columns.find { |c| c.name == name } || fail!("Unknown option #{name}, see config:list")
      end

      def cast(column, value)
        return nil if column.null && value == ""
        case column.type
        when :integer then Integer(value)
        when :boolean then value.truthy?
        when :jsonb then JSON.parse(value)
        else value
        end
      rescue ArgumentError, JSON::ParserError
        fail!("Invalid value for #{column.name}: #{value}")
      end
    end
  end
end
