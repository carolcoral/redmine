require 'net/http'
require 'json'
require 'uri'

module WebhookTaskReminder
  class HolidayCalendar
    CACHE_TTL = 30.days
    BASE_URL = 'https://unpkg.com/holiday-calendar@1.3.0/data/CN'.freeze

    def initialize(cache: Rails.cache, logger: Rails.logger)
      @cache = cache
      @logger = logger
    end

    # 返回 true/false：指定日期是否需要上班（影响是否触发提醒）
    # - public_holiday：休假
    # - transfer_workday：调休上班（即便周末也算工作日）
    # 其它情况：按周末规则判断（周一至周五工作、周末不工作）
    def workday?(date)
      date = date.to_date

      info = date_info(date)
      if info&.fetch('type', nil) == 'transfer_workday'
        return true
      end
      if info&.fetch('type', nil) == 'public_holiday'
        return false
      end

      !(date.saturday? || date.sunday?)
    end

    def date_info(date)
      year = date.year
      data = load_year(year)
      return nil unless data.is_a?(Hash)

      dates = data['dates']
      return nil unless dates.is_a?(Array)

      dates.find { |d| d.is_a?(Hash) && d['date'] == date.strftime('%Y-%m-%d') }
    end

    def load_year(year)
      year = year.to_i
      cache_key = "redmine_webhook:holiday_calendar:CN:#{year}"

      @cache.fetch(cache_key, expires_in: CACHE_TTL) do
        fetch_year!(year)
      end
    rescue StandardError => e
      @logger.error "[WebhookTaskReminder] HolidayCalendar load_year failed: year=#{year} err=#{e.class}:#{e.message}"
      nil
    end

    def fetch_year!(year)
      url = "#{BASE_URL}/#{year}.json"
      uri = URI.parse(url)
      res = Net::HTTP.get_response(uri)
      unless res.is_a?(Net::HTTPSuccess)
        raise "holiday_calendar http=#{res.code} url=#{url}"
      end

      parsed = JSON.parse(res.body)
      unless parsed.is_a?(Hash) && parsed['year'].to_i == year
        raise "holiday_calendar invalid payload for year=#{year}"
      end

      parsed
    end
  end
end

