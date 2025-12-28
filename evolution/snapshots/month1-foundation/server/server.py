from flask import Flask, request, send_file
import os

app = Flask(__name__)
UPLOAD_DIR = "screenshots"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@app.route("/upload", methods=["POST"])
def upload():
    with open(f"{UPLOAD_DIR}/latest.jpg", "wb") as f:
        f.write(request.data)
    return "OK"

@app.route("/latest")
def latest():
    return send_file(f"{UPLOAD_DIR}/latest.jpg")

@app.route("/")
def index():
    return send_file("index.html")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
