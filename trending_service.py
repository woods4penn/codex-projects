from __future__ import annotations

from flask import Flask, jsonify, request
from yahoo_trending_tickers import get_trending_symbols, enrich_ticker

app = Flask(__name__)


@app.route("/trending")
def trending():
    region = request.args.get("region", "US")
    try:
        limit = int(request.args.get("limit", "20"))
    except ValueError:
        limit = 20

    symbols = get_trending_symbols(region=region, limit=limit)
    rows = [enrich_ticker(sym) for sym in symbols]
    return jsonify(rows)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
