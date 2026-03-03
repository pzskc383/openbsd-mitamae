require "logger"
require "irb"

class RakeLogger < Logger
  class Formatter < Logger::Formatter
    FORMAT = "%s [%s #%s] %s: %s\n".freeze
    DATETIME_FORMAT = '%m.%d %H:%M:%S'.freeze

    SEV_COLOR_MAP = {
      DEBUG: [:CYAN],
      INFO: [:BLUE],
      WARN: [:YELLOW],
      ERROR: [:RED],
      FATAL: %i[RED BOLD]
    }.freeze

    def call(sev, time, prog, msg)
      colors_seq = color_for_sev(sev)
      sprintf_args = [
        colorize(sev.to_s.upcase, colors_seq),
        format_datetime(time),
        Process.pid,
        prog
      ]

      format_msg(msg).map do |line|
        msg_text = colorize(line, colors_seq)
        format(FORMAT, *sprintf_args, msg_text)
      end.join("\n")
    end

    private

    def format_datetime(time)
      time.strftime(@datetime_format || DATETIME_FORMAT)
    end

    def format_msg(msg)
      case msg
      when ::String
        [msg.dump]
      when ::Exception
        ["#{msg.message} (#{msg.class})"].then do |r|
          r << msg.backtrace.join("\n") if msg.backtrace
        end
      else
        [msg.inspect]
      end
    end

    def color_for_sev(sev)
      SEV_COLOR_MAP.fetch(sev.to_s.upcase.to_sym, [])
    end

    def colorize(text, seq)
      IRB::Color.colorize(text, seq)
    end
  end

  include Singleton

  def initialize()
    super(
      $stderr,
      level: :info,
      formatter: Formatter.new
    )
  end
end
