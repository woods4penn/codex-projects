#!/usr/bin/env python3
"""Fetch Yahoo Finance trending tickers and enrich with market data.

Usage examples:
  python yahoo_trending_tickers.py --region US --limit 25
  python yahoo_trending_tickers.py --region US --output csv > trending.csv
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from typing import Any

import requests
import yfinance as yf

YAHOO_TRENDING_URL = "https://query1.finance.yahoo.com/v1/finance/trending/{region}"


def get_trending_symbols(region: str = "US", limit: int = 100) -> list[str]:
    """Return trending symbols from Yahoo Finance for a given region."""
    url = YAHOO_TRENDING_URL.format(region=region)
    response = requests.get(url, timeout=20)
    response.raise_for_status()
    payload = response.json()

    quotes = (
        payload.get("finance", {})
        .get("result", [{}])[0]
        .get("quotes", [])
    )

    symbols: list[str] = []
    for quote in quotes:
        symbol = quote.get("symbol")
        if symbol and symbol not in symbols:
            symbols.append(symbol)
        if len(symbols) >= limit:
            break
    return symbols


def enrich_ticker(symbol: str) -> dict[str, Any]:
    """Fetch key quote/fundamental data for a symbol via yfinance."""
    ticker = yf.Ticker(symbol)

    info = ticker.info or {}
    fast_info = dict(ticker.fast_info or {})

    # Normalize to a stable subset of fields.
    return {
        "symbol": symbol,
        "shortName": info.get("shortName"),
        "longName": info.get("longName"),
        "quoteType": info.get("quoteType"),
        "exchange": info.get("exchange"),
        "currency": info.get("currency"),
        "regularMarketPrice": info.get("regularMarketPrice") or fast_info.get("lastPrice"),
        "regularMarketChangePercent": info.get("regularMarketChangePercent"),
        "regularMarketVolume": info.get("regularMarketVolume") or fast_info.get("lastVolume"),
        "averageDailyVolume3Month": info.get("averageDailyVolume3Month"),
        "marketCap": info.get("marketCap") or fast_info.get("marketCap"),
        "fiftyTwoWeekLow": info.get("fiftyTwoWeekLow") or fast_info.get("yearLow"),
        "fiftyTwoWeekHigh": info.get("fiftyTwoWeekHigh") or fast_info.get("yearHigh"),
        "sector": info.get("sector"),
        "industry": info.get("industry"),
        "website": info.get("website"),
    }


def to_csv(rows: list[dict[str, Any]], out_stream: Any) -> None:
    if not rows:
        return
    fieldnames = list(rows[0].keys())
    writer = csv.DictWriter(out_stream, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--region", default="US", help="Yahoo region code (default: US)")
    parser.add_argument("--limit", type=int, default=20, help="Max number of trending symbols")
    parser.add_argument(
        "--output",
        choices=["json", "csv"],
        default="json",
        help="Output format",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        symbols = get_trending_symbols(region=args.region, limit=args.limit)
        rows = [enrich_ticker(symbol) for symbol in symbols]
    except requests.RequestException as exc:
        print(f"Network/API error while loading trending tickers: {exc}", file=sys.stderr)
        return 2
    except Exception as exc:  # noqa: BLE001
        print(f"Unexpected error: {exc}", file=sys.stderr)
        return 1

    if args.output == "csv":
        to_csv(rows, sys.stdout)
    else:
        print(json.dumps(rows, indent=2, default=str))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
