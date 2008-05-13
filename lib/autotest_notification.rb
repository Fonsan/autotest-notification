$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module AutotestNotification
  FAIL    = -1
  PENDING = 0
  SUCCESS = 1

  EXPIRATION_IN_SECONDS = 3

  IMAGES_DIRECTORY = File.expand_path(File.dirname(__FILE__) + "/../images/")
  SUCCESS_IMAGE    = "#{IMAGES_DIRECTORY}/pass.png"
  FAIL_IMAGE       = "#{IMAGES_DIRECTORY}/fail.png"

  Autotest.add_hook :ran_command do |at|
    result = at.results.split("\n").last.to_s
    if result

      # Test::Unit
      tests      = result =~ /(\d+) test/ ? $1.to_i : 0
      assertions = result =~ /(\d+) assertion/ ? $1.to_i : 0
      errors     = result =~ /(\d+) error/ ? $1.to_i : 0

      # RSpec
      examples   = result =~ /(\d+) example/ ? $1.to_i : 0
      pendings   = result =~ /(\d+) pending/ ? $1.to_i : 0

      # Shared
      failures   = result =~ /(\d+) failure/ ? $1.to_i : 0

      code = 32
      msg = if result =~ /test/
        code = 31 if failures > 0 || errors > 0
        "#{pluralize('test', tests)}, #{pluralize('assertion', assertions)}, #{pluralize('failure', failures)}, #{pluralize('error', errors)}"
      else
        code = (failures > 0) ? 31 : (pendings > 0) ? 33 : 32
        "#{pluralize('example', examples)}, #{pluralize('failure', failures)}, #{pendings} pending"
      end

      if failures > 0 || errors > 0
        notify "FAIL", msg, FAIL_IMAGE, 2
      else
        notify "Pass", msg, SUCCESS_IMAGE
      end

      puts "\e[#{code}m#{'=' * 80}\e[0m\n\n"
    end
  end

  class << self
    def notify(title, msg, img = SUCCESS_IMAGE, pri = 0)
      case RUBY_PLATFORM
      when /linux/
        has_notify?? notify_send(title, msg, img) : kdialog(title, msg, img)
      when /darwin/
        growl(title, msg, img, pri)
      when /cygwin/
        img = `cygpath -m #{img}`
        snarl(title, msg, img.strip)
      when /mswin/
        snarl(title, msg, img)
      end
    end

    def pluralize(text, number)
      "#{number} #{text}#{'s' if number != 1}"
    end

    def growl(title, msg, img, pri = 0)
      system "growlnotify -n autotest --image #{img} -p #{pri} -m #{msg.inspect} #{title}"
    end

    def notify_send(title, msg, img)
      system "notify-send -t #{EXPIRATION_IN_SECONDS * 1000} -i #{img} '#{title}' '#{msg}'"
    end

    def kdialog(title, msg, img)
      system "kdialog --title '#{title}' --passivepopup '#{msg}' #{EXPIRATION_IN_SECONDS}"
    end

    def has_notify?
      system "which notify-send 2> /dev/null"
    end

    def snarl(title, msg, img)
      message = "sncmd /m '#{title}' '#{msg}' '#{img}' /t #{EXPIRATION_IN_SECONDS}"
      system message
    end
  end
end
