# frozen_string_literal: true

require "json"
require "logger"
require "time"
require "faraday"

module MarketDataApp
  class API
    HOST = "https://api.marketdata.app/v1/"

    JSON_CONTENT_TYPE = "application/json"
    SUCCESS_STATUSES = [200, 203].freeze

    RETRY_WAIT = 1
    MAX_RETRY = 6
    MAX_BACKOFF = 32
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 60

    attr_reader :token

    def initialize(token = nil)
      @token = token || ENV["MARKET_DATA_APP_API_KEY"] || ENV["MARKETDATA_TOKEN"]
    end

    def option_chain(ticker, **params)
      request("options/chain/#{ticker}/", params)
    end

    def option_quote(option_symbol, **params)
      request("options/quotes/#{option_symbol}/", params)
    end

    def stock_quote(symbol, **params)
      request("stocks/quotes/#{symbol}/", params)
    end

    def stock_quotes(symbols, **params)
      symbols = Array(symbols).join(",")
      request("stocks/quotes/", params.merge(symbols: symbols))
    end

    def option_expirations(ticker, **params)
      request("options/expirations/#{ticker}/", params)
    end

    # Escape hatch for endpoints added by MarketData.app before this gem has a wrapper.
    def get(path, params = {})
      request(path, params)
    end

    private

      def request(path, params = {})
        retries = 0
        full_url = absolute_url(path)
        req_args = params.compact

        begin
          response = connection.get(full_url, req_args)
          return parse_response(response) if success?(response)

          handle_error_response!(response)
        rescue ServiceUnavailable => e
          if retries < MAX_RETRY
            retries += 1
            wait = backoff_sleep(e.retry_after, retries)
            logger.info("MarketData.app unavailable for #{request_log_line(full_url, req_args)}: #{e.message}; retrying #{retries}/#{MAX_RETRY} in #{wait.round(1)}s")
            sleep wait
            retry
          end

          raise
        rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
          if retries < MAX_RETRY
            retries += 1
            wait = backoff_sleep(nil, retries)
            logger.info("MarketData.app connection error for #{request_log_line(full_url, req_args)}: #{e.class}: #{e.message}; retrying #{retries}/#{MAX_RETRY} in #{wait.round(1)}s")
            sleep wait
            retry
          end

          raise
        end
      end

      def parse_response(response)
        ensure_json_response!(response)
        JSON.parse(response.body)
      rescue JSON::ParserError => e
        raise InvalidResponse, e.message
      end

      def success?(response)
        SUCCESS_STATUSES.include?(response.status)
      end

      def handle_error_response!(response)
        case response.status
        when 401
          raise InvalidToken, error_message_from_body(response.body, response.status)
        when 403
          raise AccessDenied, error_message_from_body(response.body, response.status)
        when 404
          raise NotFound, error_message_from_body(response.body, response.status)
        when 429, 500..599
          raise ServiceUnavailable.new(
            error_message_from_body(response.body, response.status),
            http_status: response.status,
            retry_after: parse_retry_after(response)
          )
        else
          raise Error, error_message_from_body(response.body, response.status)
        end
      end

      def ensure_json_response!(response)
        content_type = response.headers["content-type"] || response.headers["Content-Type"]
        return if content_type&.include?(JSON_CONTENT_TYPE)

        raise InvalidResponse, "Expected JSON response, got #{content_type || "unknown"}"
      end

      def connection
        @connection ||= Faraday.new do |f|
          f.headers["Accept"] = JSON_CONTENT_TYPE
          f.headers["Authorization"] = "Bearer #{token}" if token && !token.empty?
          f.options.open_timeout = OPEN_TIMEOUT
          f.options.timeout = READ_TIMEOUT
        end
      end

      def absolute_url(path)
        path = path.to_s
        return path if path.start_with?("http://", "https://")

        "#{HOST}#{path.sub(%r{\A/+}, "")}"
      end

      def error_message_from_body(body, status)
        detail = parse_error_detail(body)
        detail.empty? ? "HTTP #{status}" : "#{status} #{detail}"
      end

      def parse_error_detail(body)
        return "" if body.nil?

        b = body.to_s
        return b.byteslice(0, 240) if b.strip.empty?

        json = JSON.parse(b)
        msg = json["error"] || json["message"] || json["detail"] || json["errmsg"] || json["s"]
        s = msg&.to_s
        s = b.byteslice(0, 240) if s.nil? || s.empty?
        s.byteslice(0, 240)
      rescue JSON::ParserError
        body.to_s.byteslice(0, 240)
      end

      def parse_retry_after(response)
        raw = response.headers["retry-after"] || response.headers["Retry-After"]
        return nil if raw.nil? || raw.to_s.strip.empty?

        s = raw.to_s.strip
        if /\A\d+\z/.match?(s)
          s.to_i.clamp(1, 3600)
        else
          seconds = (Time.httpdate(s) - Time.now).to_i
          seconds.clamp(1, 3600) if seconds.positive?
        end
      rescue ArgumentError, TypeError
        nil
      end

      def backoff_sleep(retry_after, retries)
        return [retry_after.to_f, 3600].min if retry_after

        [RETRY_WAIT * (2**(retries - 1)), MAX_BACKOFF].min + rand
      end

      def request_log_line(url, params)
        filtered = params.transform_keys(&:to_s).reject { |k, _| k == "token" }
        filtered.empty? ? url : "#{url}?#{filtered}"
      end

      def logger
        @logger ||= defined?(Rails) ? Rails.logger : Logger.new($stdout)
      end
  end
end
