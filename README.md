# market-data-app

Ruby client for the [MarketData.app](https://www.marketdata.app/) API.

## Usage

Set a bearer token in the environment:

```bash
MARKET_DATA_APP_API_KEY=...
```

Then call the API:

```ruby
api = MarketDataApp::API.new

api.option_chain("AAPL", expiration: "2027-12-17")
api.option_quote("AAPL271217C00300000")
api.stock_quote("AAPL")
api.stock_quotes(%w[AAPL MSFT])
api.option_expirations("AAPL")
```

Use `get` as an escape hatch for endpoints not yet wrapped:

```ruby
api.get("options/chain/AAPL/", date: "2025-08-08")
```
