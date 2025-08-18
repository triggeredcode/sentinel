#!/usr/bin/env python3
"""Sentinel Server - receives screenshots"""

from flask import Flask, request, send_from_directory
from pathlib import Path
from datetime import datetime

app = Flask(__name__)
STORAGE = Path("/tmp/sentinel_images")
STORAGE.mkdir(exist_ok=True)

@app.route("/upload", methods=["POST"])
def upload():
    data = request.get_data()
    if not data:
        return "No data", 400
    
    filename = f"shot_{datetime.now().strftime('%H%M%S')}.jpg"
    (STORAGE / filename).write_bytes(data)
    print(f"Saved: {filename} ({len(data)} bytes)")
    return "OK"

@app.route("/latest")
def latest():
    images = sorted(STORAGE.glob("*.jpg"))
    if not images:
        return "No images", 404
    return send_from_directory(STORAGE, images[-1].name)

if __name__ == "__main__":
    print("Server starting on :8000")
    app.run(host="0.0.0.0", port=8000)
