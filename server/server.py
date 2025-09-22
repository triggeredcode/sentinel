#!/usr/bin/env python3
"""Sentinel Server - HTTPS with TLS 1.3"""

import os
import ssl
from flask import Flask, request, send_from_directory, send_file, abort
from pathlib import Path
from datetime import datetime

app = Flask(__name__)
STORAGE = Path("/tmp/sentinel_images")
STORAGE.mkdir(exist_ok=True)
CERT_DIR = Path.home() / ".sentinel" / "certs"

AUTH_TOKEN = os.environ.get("SENTINEL_TOKEN", "dev-token-change-me")

def check_auth():
    token = request.headers.get("X-Auth-Token")
    if token != AUTH_TOKEN:
        abort(401)

@app.route("/")
def index():
    return send_file("index.html")

@app.route("/upload", methods=["POST"])
def upload():
    check_auth()
    data = request.get_data()
    if not data:
        return "No data", 400
    
    filename = f"shot_{datetime.now().strftime('%H%M%S_%f')}.jpg"
    (STORAGE / filename).write_bytes(data)
    return {"filename": filename}

@app.route("/latest")
def latest():
    images = sorted(STORAGE.glob("*.jpg"))
    if not images:
        return "No images", 404
    return send_from_directory(STORAGE, images[-1].name)

@app.route("/images")
def list_images():
    images = sorted(STORAGE.glob("*.jpg"), reverse=True)
    return {"images": [{"name": i.name, "size": i.stat().st_size} for i in images[:10]]}

if __name__ == "__main__":
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.minimum_version = ssl.TLSVersion.TLSv1_3
    ctx.load_cert_chain(CERT_DIR / "server.crt", CERT_DIR / "server.key")
    
    print(f"HTTPS server starting on :8000")
    app.run(host="0.0.0.0", port=8000, ssl_context=ctx)
