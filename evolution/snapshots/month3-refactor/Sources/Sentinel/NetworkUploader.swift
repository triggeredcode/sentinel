import Foundation

class NetworkUploader: NSObject, URLSessionDelegate {
    private var session: URLSession!
    var serverURL = "https://localhost:8443/upload"
    var authToken: String?
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        authToken = KeychainManager.shared.getToken()
    }
    
    func upload(_ data: Data) {
        var request = URLRequest(url: URL(string: serverURL)!)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue(token, forHTTPHeaderField: "X-Auth-Token")
        }
        request.httpBody = data
        session.dataTask(with: request).resume()
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Trust self-signed certs for local development
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
