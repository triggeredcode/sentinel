import Foundation

/// Handles secure uploads to the Sentinel server
class NetworkUploader {
    let serverURL: URL
    let token: String?
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.tlsMinimumSupportedProtocolVersion = .TLSv13
        return URLSession(configuration: config, delegate: TLSDelegate(), delegateQueue: nil)
    }()
    
    init(host: String = "127.0.0.1", port: Int = 8000, token: String? = nil) {
        self.serverURL = URL(string: "https://\(host):\(port)/upload")!
        self.token = token ?? KeychainHelper.getToken()
    }
    
    func upload(_ imageData: Data, completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        
        if let token = token {
            request.setValue(token, forHTTPHeaderField: "X-Auth-Token")
        }
        
        session.uploadTask(with: request, from: imageData) { _, response, error in
            let success = (response as? HTTPURLResponse)?.statusCode == 200 && error == nil
            DispatchQueue.main.async { completion(success) }
        }.resume()
    }
}

// Trust self-signed certs for local development
class TLSDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
