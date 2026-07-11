# frozen_string_literal: true

require_relative "market_data_app/version"

module MarketDataApp
  class Error < StandardError; end
  class InvalidToken < Error; end
  class AccessDenied < Error; end
  class NotFound < Error; end
  class InvalidResponse < Error; end

  class ServiceUnavailable < Error
    attr_reader :http_status, :retry_after

    def initialize(message, http_status: nil, retry_after: nil)
      super(message)
      @http_status = http_status
      @retry_after = retry_after
    end
  end
end

require_relative "market_data_app/api"
