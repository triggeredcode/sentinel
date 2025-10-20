import Foundation
import Network

/// Built-in HTTP server using Network.framework
final class HTTPServer {
    private var listener: NWListener?
    private let port: UInt16
    private let storageDir: URL
    private let queue = DispatchQueue(label: "sentinel.httpserver")
    
    init(port: UInt16 = 8000) {
        self.port = port
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDir = appSupport.appendingPathComponent("Sentinel")
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    }
    
    func start() -> Bool {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            
            listener?.stateUpdateHandler = { state in
                if case .ready = state {
                    Logger.shared.log("HTTP server listening on port \(self.port)")
                }
            }
            
            listener?.newConnectionHandler = { [weak self] conn in
                self?.handleConnection(conn)
            }
            
            listener?.start(queue: queue)
            return true
        } catch {
            Logger.shared.log("Failed to start server: \(error)", level: .error)
            return false
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let self = self, let data = data,
                  let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            
            self.routeRequest(request, connection: connection)
        }
    }
    
    private func routeRequest(_ request: String, connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return }
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return }
        
        let method = parts[0]
        let path = parts[1].components(separatedBy: "?").first ?? parts[1]
        
        switch (method, path) {
        case ("GET", "/"):
            serveViewer(connection)
        case ("GET", "/images"):
            serveImageList(connection)
        case ("GET", _) where path.hasPrefix("/images/"):
            serveImage(String(path.dropFirst(8)), connection)
        default:
            send404(connection)
        }
    }
    
    private func serveViewer(_ connection: NWConnection) {
        let html = Self.viewerHTML
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: \(html.utf8.count)\r\n\r\n\(html)"
        send(response, to: connection)
    }
    
    private func serveImageList(_ connection: NWConnection) {
        var images: [[String: Any]] = []
        if let files = try? FileManager.default.contentsOfDirectory(at: storageDir, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for file in files where file.pathExtension == "jpg" {
                if let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                    images.append(["filename": file.lastPathComponent, "timestamp": ISO8601DateFormatter().string(from: date)])
                }
            }
        }
        images.sort { ($0["timestamp"] as? String ?? "") > ($1["timestamp"] as? String ?? "") }
        
        let json = (try? JSONSerialization.data(withJSONObject: images)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(json.utf8.count)\r\n\r\n\(json)"
        send(response, to: connection)
    }
    
    private func serveImage(_ filename: String, _ connection: NWConnection) {
        guard !filename.contains(".."),
              let data = try? Data(contentsOf: storageDir.appendingPathComponent(filename)) else {
            send404(connection)
            return
        }
        
        let header = "HTTP/1.1 200 OK\r\nContent-Type: image/jpeg\r\nContent-Length: \(data.count)\r\n\r\n"
        var response = header.data(using: .utf8)!
        response.append(data)
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }
    
    private func send404(_ connection: NWConnection) {
        send("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n", to: connection)
    }
    
    private func send(_ response: String, to connection: NWConnection) {
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in connection.cancel() })
    }
    
    private static let viewerHTML = """
    <!DOCTYPE html>
    <html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Sentinel</title>
    <style>*{margin:0;padding:0;box-sizing:border-box}body{background:#0a0a0a;color:#fff;font-family:system-ui}
    .container{max-width:800px;margin:0 auto;padding:16px}h1{font-size:1.5rem;margin-bottom:16px}
    img{max-width:100%;border-radius:8px}</style></head>
    <body><div class="container"><h1>Sentinel</h1><img id="img"></div>
    <script>
    async function refresh(){
        const r=await fetch('/images');
        const imgs=await r.json();
        if(imgs.length)document.getElementById('img').src='/images/'+imgs[0].filename+'?'+Date.now();
    }
    refresh();setInterval(refresh,5000);
    </script></body></html>
    """
}
