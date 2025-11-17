#!/usr/bin/env python3
"""
Flask API for Grow Station

Endpoints:
- GET  /api/sensor     -> Return latest sensor JSON stored at /var/www/data/sensor.json
- POST /api/sensor     -> Accept JSON and store at /var/www/data/sensor.json

Notes:
- Avoids hardcoding host static IP (handled externally). The ESP8266 should POST to http://<SERVER_IP>/api/sensor
- BusyBox/OpenRC friendly. Use gunicorn in production (see docs).
- Minimal dependencies (Flask). No DB for simplicity; storing as a single JSON file.

JSON schema (expected from ESP8266):
{
  "device": "esp8266-grow-controller-01",
  "temp_c": 24.8,
  "humidity": 58,
  "timestamp": 1731809160,
  "rssi": -61
}
"""

import json
import os
from datetime import datetime
from typing import Any, Dict, Tuple

from flask import Flask, request, jsonify, make_response

# Constants
DATA_DIR = "/var/www/data"
DATA_FILE = os.path.join(DATA_DIR, "sensor.json")

app = Flask(__name__)


def ensure_data_dir() -> None:
    """Ensure data directory exists with correct permissions."""
    try:
        os.makedirs(DATA_DIR, exist_ok=True)
    except Exception:
        # If this fails, the POST route will surface an error
        pass


def load_sensor_data() -> Tuple[Dict[str, Any], int]:
    """Load the latest sensor JSON from disk.

    Returns: (payload, status_code)
    """
    if not os.path.exists(DATA_FILE):
        return ({
            "status": "empty",
            "message": "No sensor data yet",
            "timestamp_server": int(datetime.utcnow().timestamp())
        }, 200)

    try:
        with open(DATA_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        # Attach a server timestamp for reference
        data["timestamp_server"] = int(datetime.utcnow().timestamp())
        return (data, 200)
    except json.JSONDecodeError:
        return ({"error": "Corrupt JSON file"}, 500)
    except Exception as e:
        return ({"error": f"Read error: {e}"}, 500)


def is_valid_payload(payload: Dict[str, Any]) -> Tuple[bool, str]:
    """Basic payload validation against the expected schema."""
    required = ["device", "temp_c", "humidity", "timestamp", "rssi"]
    for key in required:
        if key not in payload:
            return False, f"Missing field: {key}"

    # Type checks (lenient conversions if possible)
    try:
        float(payload["temp_c"])  # temp in °C numeric
        int(payload["humidity"])  # humidity percent integer
        int(payload["timestamp"]) # epoch seconds
        int(payload["rssi"])      # WiFi RSSI dBm
    except Exception:
        return False, "Invalid types in fields"

    if not isinstance(payload["device"], str):
        return False, "Field 'device' must be string"

    return True, "ok"


@app.after_request
def add_cors_headers(resp):
    # Keep CORS simple without adding flask-cors dependency
    resp.headers["Access-Control-Allow-Origin"] = "*"
    resp.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    resp.headers["Access-Control-Allow-Headers"] = "Content-Type"
    return resp


@app.route("/api/sensor", methods=["GET"])
def get_sensor():
    ensure_data_dir()
    payload, code = load_sensor_data()
    return make_response(jsonify(payload), code)


@app.route("/api/sensor", methods=["POST", "OPTIONS"])
def post_sensor():
    if request.method == "OPTIONS":
        return ("", 204)

    ensure_data_dir()
    if not request.is_json:
        return make_response(jsonify({"error": "Expected application/json"}), 415)

    try:
        payload = request.get_json(force=True, silent=False)
    except Exception as e:
        return make_response(jsonify({"error": f"JSON parse error: {e}"}), 400)

    ok, msg = is_valid_payload(payload)
    if not ok:
        return make_response(jsonify({"error": msg}), 400)

    # Store atomically: write temp file then replace
    tmp_file = DATA_FILE + ".tmp"
    try:
        with open(tmp_file, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        os.replace(tmp_file, DATA_FILE)
    except Exception as e:
        return make_response(jsonify({"error": f"Write error: {e}"}), 500)

    return make_response(jsonify({"status": "ok"}), 201)


@app.route("/api/health", methods=["GET"])  # simple health check
def health():
    return make_response(jsonify({"status": "up"}), 200)


if __name__ == "__main__":
    # Dev/test server; for production use gunicorn (see docs)
    app.run(host="127.0.0.1", port=5000, debug=False)
