import Foundation
import Network

/// Built-in HTTP server using Network.framework
/// No external dependencies - everything runs in-process
final class HTTPServer: @unchecked Sendable {
    
    private var listener: NWListener?
    private let port: UInt16
    private let storageDir: URL
    private let maxImages = 5
    
    private let queue = DispatchQueue(label: "com.sentinel.httpserver")
    
    init(port: UInt16 = 8000) {
        self.port = port
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.storageDir = appSupport.appendingPathComponent("Sentinel")
        
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    }
    
    func start() -> Bool {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            
            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    Logger.shared.log("HTTP server listening on port \(self?.port ?? 0)")
                case .failed(let error):
                    Logger.shared.log("HTTP server failed: \(error)", level: .error)
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: queue)
            return true
            
        } catch {
            Logger.shared.log("Failed to start HTTP server: \(error)", level: .error)
            return false
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        Logger.shared.log("HTTP server stopped")
    }
    
    // MARK: - Connection Handling
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else {
                connection.cancel()
                return
            }
            
            self.handleRequest(data: data, connection: connection)
        }
    }
    
    private func handleRequest(data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendError(connection: connection, status: 400, message: "Bad Request")
            return
        }
        
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendError(connection: connection, status: 400, message: "Bad Request")
            return
        }
        
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendError(connection: connection, status: 400, message: "Bad Request")
            return
        }
        
        let method = parts[0]
        let path = parts[1].components(separatedBy: "?").first ?? parts[1]
        
        // Route the request
        switch (method, path) {
        case ("GET", "/"):
            serveHTML(connection: connection)
        case ("GET", "/health"):
            serveHealth(connection: connection)
        case ("GET", "/images"):
            serveImageList(connection: connection)
        case ("GET", _) where path.hasPrefix("/images/"):
            let filename = String(path.dropFirst("/images/".count))
            serveImage(connection: connection, filename: filename)
        case ("POST", "/trigger-capture"):
            serveTriggerCapture(connection: connection)
        case ("GET", "/notifications"):
            serveNotifications(connection: connection)
        case ("POST", "/clear-notifications"):
            clearNotifications(connection: connection)
        default:
            sendError(connection: connection, status: 404, message: "Not Found")
        }
    }
    
    // MARK: - Route Handlers
    
    private func serveHTML(connection: NWConnection) {
        let html = Self.viewerHTML
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(html.utf8.count)\r
        Cache-Control: no-cache\r
        Connection: close\r
        \r
        \(html)
        """
        sendResponse(connection: connection, response: response)
    }
    
    private func serveHealth(connection: NWConnection) {
        let json = #"{"status":"healthy","timestamp":"\#(ISO8601DateFormatter().string(from: Date()))"}"#
        sendJSON(connection: connection, json: json)
    }
    
    private func serveImageList(connection: NWConnection) {
        var images: [[String: Any]] = []
        
        if let files = try? FileManager.default.contentsOfDirectory(
            at: storageDir,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) {
            for file in files where file.pathExtension == "jpg" {
                if let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                   let modDate = attrs.contentModificationDate,
                   let size = attrs.fileSize {
                    images.append([
                        "filename": file.lastPathComponent,
                        "timestamp": ISO8601DateFormatter().string(from: modDate),
                        "size": size
                    ])
                }
            }
        }
        
        images.sort { ($0["timestamp"] as? String ?? "") > ($1["timestamp"] as? String ?? "") }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: images),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            sendJSON(connection: connection, json: jsonString)
        } else {
            sendJSON(connection: connection, json: "[]")
        }
    }
    
    private func serveImage(connection: NWConnection, filename: String) {
        // Security: prevent directory traversal
        guard !filename.contains("..") && !filename.contains("/") else {
            sendError(connection: connection, status: 400, message: "Invalid filename")
            return
        }
        
        let fileURL = storageDir.appendingPathComponent(filename)
        
        guard let imageData = try? Data(contentsOf: fileURL) else {
            sendError(connection: connection, status: 404, message: "Image not found")
            return
        }
        
        let header = """
        HTTP/1.1 200 OK\r
        Content-Type: image/jpeg\r
        Content-Length: \(imageData.count)\r
        Cache-Control: no-cache\r
        Connection: close\r
        \r\n
        """
        
        var responseData = header.data(using: .utf8)!
        responseData.append(imageData)
        
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func serveTriggerCapture(connection: NWConnection) {
        NotificationCenter.default.post(name: .captureRequested, object: nil)
        let json = #"{"success":true,"message":"Capture requested"}"#
        sendJSON(connection: connection, json: json)
    }
    
    private func serveNotifications(connection: NWConnection) {
        let json = NotificationMonitor.shared.getEventsJSON()
        sendJSON(connection: connection, json: json)
    }
    
    private func clearNotifications(connection: NWConnection) {
        NotificationMonitor.shared.clearEvents()
        let json = #"{"success":true}"#
        sendJSON(connection: connection, json: json)
    }
    
    // MARK: - Response Helpers
    
    private func sendJSON(connection: NWConnection, json: String) {
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json\r
        Content-Length: \(json.utf8.count)\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r
        \(json)
        """
        sendResponse(connection: connection, response: response)
    }
    
    private func sendError(connection: NWConnection, status: Int, message: String) {
        let statusText: String
        switch status {
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        default: statusText = "Error"
        }
        
        let body = #"{"error":"\#(message)"}"#
        let response = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        sendResponse(connection: connection, response: response)
    }
    
    private func sendResponse(connection: NWConnection, response: String) {
        let data = response.data(using: .utf8)!
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    // MARK: - Embedded Viewer HTML
    
    private static let viewerHTML = #"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <meta name="apple-mobile-web-app-capable" content="yes">
        <title>Sentinel</title>
        <style>
            * { box-sizing: border-box; margin: 0; padding: 0; -webkit-user-select: none; user-select: none; }
            :root {
                --bg: #0a0a0a; --bg2: #1a1a1a; --text: #fff;
                --text2: #888; --accent: #007aff; --border: #333;
                --success: #34c759; --warning: #ff9500; --red: #ff3b30;
            }
            html, body { height: 100%; overflow: hidden; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                background: var(--bg); color: var(--text);
                display: flex; flex-direction: column;
                padding: max(8px, env(safe-area-inset-top)) 8px max(8px, env(safe-area-inset-bottom));
            }
            header {
                display: flex; justify-content: space-between; align-items: center;
                padding: 8px; flex-shrink: 0;
            }
            h1 { font-size: 1.25rem; }
            .status { display: flex; align-items: center; gap: 6px; font-size: 0.75rem; color: var(--text2); }
            .dot { width: 6px; height: 6px; border-radius: 50%; background: var(--success); }
            .dot.live { animation: pulse 2s infinite; }
            @keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: 0.5; } }
            
            .tabs { display: flex; gap: 4px; padding: 0 8px 8px; flex-shrink: 0; }
            .tab { flex: 1; padding: 10px; background: var(--bg2); border: none; color: var(--text2);
                border-radius: 8px; font-size: 0.875rem; font-weight: 500; }
            .tab.active { background: var(--accent); color: white; }
            .tab-badge { background: var(--red); color: white; font-size: 0.625rem;
                padding: 2px 6px; border-radius: 10px; margin-left: 4px; }
            
            .panel { display: none; flex: 1; flex-direction: column; overflow: hidden; }
            .panel.active { display: flex; }
            
            .controls { display: flex; gap: 6px; padding: 8px; flex-shrink: 0; }
            button {
                flex: 1; background: var(--accent); color: white; border: none;
                padding: 10px 8px; border-radius: 8px; font-size: 0.8rem; font-weight: 500;
            }
            button:active { opacity: 0.8; }
            button.secondary { background: var(--bg2); border: 1px solid var(--border); }
            button.small { flex: 0; padding: 10px; min-width: 44px; }
            
            .image-container {
                flex: 1; overflow: hidden; position: relative;
                background: var(--bg2); border-radius: 8px; margin: 0 8px;
                touch-action: none;
            }
            .image-wrapper {
                position: absolute; inset: 0;
                display: flex; align-items: center; justify-content: center;
            }
            .image-wrapper img { 
                max-width: 100%; max-height: 100%; object-fit: contain;
                transition: transform 0.15s ease-out;
            }
            .image-wrapper img.rotate-0 { transform: rotate(0deg); }
            .image-wrapper img.rotate-90 { transform: rotate(90deg); }
            .image-wrapper img.rotate-180 { transform: rotate(180deg); }
            .image-wrapper img.rotate-270 { transform: rotate(270deg); }
            .placeholder { color: var(--text2); text-align: center; padding: 40px; }
            
            .thumbs { display: flex; gap: 6px; padding: 8px; overflow-x: auto; flex-shrink: 0; }
            .thumb { width: 60px; height: 34px; flex-shrink: 0; background: var(--bg2);
                border-radius: 4px; overflow: hidden; border: 2px solid transparent; }
            .thumb.active { border-color: var(--accent); }
            .thumb img { width: 100%; height: 100%; object-fit: cover; }
            
            .notif-list { flex: 1; overflow-y: auto; padding: 8px; }
            .notif-item { background: var(--bg2); border-radius: 8px; padding: 12px; margin-bottom: 8px; }
            .notif-header { display: flex; justify-content: space-between; margin-bottom: 4px; }
            .notif-type { font-size: 0.625rem; padding: 2px 6px; border-radius: 4px;
                background: var(--border); color: var(--text2); text-transform: uppercase; }
            .notif-time { font-size: 0.75rem; color: var(--text2); }
            .notif-title { font-weight: 600; font-size: 0.875rem; margin-bottom: 2px; }
            .notif-body { font-size: 0.75rem; color: var(--text2); }
            .notif-empty { text-align: center; color: var(--text2); padding: 40px; }
            
            .toast {
                position: fixed; bottom: 80px; left: 50%; transform: translateX(-50%);
                background: var(--bg2); padding: 10px 20px; border-radius: 8px;
                opacity: 0; transition: opacity 0.3s; border: 1px solid var(--border);
                font-size: 0.875rem; z-index: 100;
            }
            .toast.show { opacity: 1; }
            .hidden { display: none !important; }
        </style>
    </head>
    <body>
        <header>
            <h1>Sentinel</h1>
            <div class="status"><div class="dot live" id="dot"></div><span id="status">Live</span></div>
        </header>
        
        <div class="tabs">
            <button class="tab active" onclick="showTab('screenshots')">📷 Screenshots</button>
            <button class="tab" onclick="showTab('notifications')" id="notif-tab">🔔 Activity<span class="tab-badge hidden" id="notif-badge">0</span></button>
        </div>
        
        <div class="panel active" id="screenshots-panel">
            <div class="controls">
                <button onclick="capture()" id="cap-btn">📸 Capture</button>
                <button class="secondary" onclick="toggleAuto()" id="auto-btn">Auto ON</button>
                <button class="secondary small" onclick="cycleRotation()">🔄</button>
            </div>
            <div class="image-container" id="container">
                <div class="image-wrapper" id="wrapper">
                    <div class="placeholder" id="ph">
                        <p>📷 Waiting for screenshots...</p>
                    </div>
                    <img id="img" class="hidden rotate-270" alt="Screenshot">
                </div>
            </div>
            <div class="thumbs" id="thumbs"></div>
        </div>
        
        <div class="panel" id="notifications-panel">
            <div class="controls">
                <button onclick="refreshNotifications()">🔄 Refresh</button>
                <button class="secondary" onclick="clearNotifications()">🗑 Clear</button>
            </div>
            <div class="notif-list" id="notif-list">
                <div class="notif-empty">No activity yet</div>
            </div>
        </div>
        
        <div class="toast" id="toast"></div>
        
        <script>
            const POLL = 5000;
            let auto = true, timer = null, current = null, images = [], notifications = [];
            let rotation = parseInt(localStorage.getItem('rotation') || '270');
            let seenNotifIds = new Set();
            
            const $ = id => document.getElementById(id);
            const img = $('img');
            
            function toast(msg) {
                const t = $('toast');
                t.textContent = msg;
                t.classList.add('show');
                setTimeout(() => t.classList.remove('show'), 2000);
            }
            
            function showTab(tab) {
                document.querySelectorAll('.tab').forEach((t,i) => 
                    t.classList.toggle('active', i === (tab === 'screenshots' ? 0 : 1)));
                document.querySelectorAll('.panel').forEach(p => 
                    p.classList.toggle('active', p.id === tab + '-panel'));
                if (tab === 'notifications') $('notif-badge').classList.add('hidden');
            }
            
            function fmt(iso) {
                return new Date(iso).toLocaleTimeString([], {hour:'2-digit',minute:'2-digit',second:'2-digit'});
            }
            
            function cycleRotation() {
                rotation = (rotation + 90) % 360;
                localStorage.setItem('rotation', rotation);
                img.className = img.className.replace(/rotate-\d+/, '') + ' rotate-' + rotation;
                toast('Rotated ' + rotation + '°');
            }
            
            async function refresh() {
                try {
                    const [imgRes, notifRes] = await Promise.all([
                        fetch('/images?t=' + Date.now()),
                        fetch('/notifications?t=' + Date.now())
                    ]);
                    
                    images = await imgRes.json();
                    const newNotifs = await notifRes.json();
                    
                    $('dot').classList.remove('error');
                    $('status').textContent = auto ? 'Live' : 'Connected';
                    
                    renderThumbs();
                    
                    let newCount = 0;
                    for (const n of newNotifs) {
                        if (!seenNotifIds.has(n.id)) { seenNotifIds.add(n.id); newCount++; }
                    }
                    notifications = newNotifs;
                    
                    if (newCount > 0 && !$('notifications-panel').classList.contains('active')) {
                        const badge = $('notif-badge');
                        badge.textContent = (parseInt(badge.textContent) || 0) + newCount;
                        badge.classList.remove('hidden');
                    }
                    
                    if ($('notifications-panel').classList.contains('active')) renderNotifications();
                    
                    if (images.length > 0 && images[0].filename !== current) {
                        load(images[0].filename);
                        if (current) toast('New screenshot!');
                    }
                } catch(e) {
                    $('dot').classList.add('error');
                    $('status').textContent = 'Offline';
                }
            }
            
            function load(fn) {
                const newImg = new Image();
                newImg.onload = () => {
                    img.src = newImg.src;
                    img.classList.remove('hidden');
                    img.className = img.className.replace(/rotate-\d+/, '') + ' rotate-' + rotation;
                    $('ph').classList.add('hidden');
                    current = fn;
                    renderThumbs();
                };
                newImg.src = '/images/' + encodeURIComponent(fn) + '?t=' + Date.now();
            }
            
            function renderThumbs() {
                $('thumbs').innerHTML = images.map(i =>
                    `<div class="thumb ${i.filename===current?'active':''}" onclick="load('${i.filename}')">
                        <img src="/images/${encodeURIComponent(i.filename)}" loading="lazy">
                    </div>`
                ).join('');
            }
            
            async function capture() {
                const btn = $('cap-btn');
                btn.disabled = true;
                btn.textContent = '⏳...';
                try {
                    await fetch('/trigger-capture', {method:'POST'});
                    toast('Capturing...');
                    setTimeout(() => { refresh(); btn.disabled = false; btn.textContent = '📸 Capture'; }, 1200);
                } catch(e) {
                    toast('Failed');
                    btn.disabled = false;
                    btn.textContent = '📸 Capture';
                }
            }
            
            function toggleAuto() {
                auto = !auto;
                $('auto-btn').textContent = auto ? 'Auto ON' : 'Auto OFF';
                $('dot').classList.toggle('live', auto);
                $('status').textContent = auto ? 'Live' : 'Connected';
                auto ? start() : stop();
                toast(auto ? 'Auto ON' : 'Auto OFF');
            }
            
            function start() { if (!timer) timer = setInterval(refresh, POLL); }
            function stop() { clearInterval(timer); timer = null; }
            
            function renderNotifications() {
                const list = $('notif-list');
                if (notifications.length === 0) {
                    list.innerHTML = '<div class="notif-empty">No activity yet</div>';
                    return;
                }
                list.innerHTML = notifications.map(n => `
                    <div class="notif-item">
                        <div class="notif-header">
                            <span class="notif-type">${n.type}</span>
                            <span class="notif-time">${fmt(n.timestamp)}</span>
                        </div>
                        <div class="notif-title">${n.title}</div>
                        <div class="notif-body">${n.body}</div>
                    </div>
                `).join('');
            }
            
            async function refreshNotifications() {
                const r = await fetch('/notifications?t=' + Date.now());
                notifications = await r.json();
                notifications.forEach(n => seenNotifIds.add(n.id));
                renderNotifications();
            }
            
            async function clearNotifications() {
                await fetch('/clear-notifications', {method:'POST'});
                notifications = [];
                seenNotifIds.clear();
                renderNotifications();
                toast('Cleared');
            }
            
            document.addEventListener('visibilitychange', () => {
                if (document.hidden) stop();
                else if (auto) { refresh(); start(); }
            });
            
            refresh();
            start();
        </script>
    </body>
    </html>
    """#
}

// Notification for capture requests from web
extension Notification.Name {
    static let captureRequested = Notification.Name("captureRequested")
}
