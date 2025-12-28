# Sentinel v0.1 - The Foundation

The initial prototype from August 2025.

## What it does
- Captures screenshot every 10 seconds
- Uploads to local Flask server
- Browser auto-refreshes to show latest

## Running

Terminal 1:
```bash
cd server && python server.py
```

Terminal 2:
```bash
swift main.swift
```

Open http://localhost:5000

## Limitations
- No encryption
- No authentication
- Hardcoded server URL
- Single file, no modularity
