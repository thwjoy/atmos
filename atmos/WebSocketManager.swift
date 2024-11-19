//
//  WebSocketManager.swift
//  atmos
//
//  Created by Tom Joy on 17/10/2024.
//

//import Foundation
//
//class WebSocketManager_: NSObject {
//    private var webSocketTask: URLSessionWebSocketTask?
//    private var urlSession: URLSession!
//    
//    // Closure to notify connection status change
//    var onConnectionChange: ((Bool) -> Void)?
//
//    // Closure to notify message receipt
//    var onMessageReceived: ((String) -> Void)?
//    
//    // Closure to notify audio
//    var onAudioReceived: ((Data, [String: Any]) -> Void)? // For audio data and accompanying metadata
//
//    
//    override init() {
//        super.init()
//        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
//    }
//
//    func connect(to url: URL) {
//        webSocketTask = urlSession.webSocketTask(with: url)
//        webSocketTask?.resume()
//        receiveMessage()
//    }
//
//    func send(message: String) {
//        let message = URLSessionWebSocketTask.Message.string(message)
//        webSocketTask?.send(message) { error in
//            if let error = error as? URLError {
//                print("Failed to send message: \(error.localizedDescription) - \(error.code.rawValue)")
////            } else if let error = error {
////                print("Failed to send message: \(error.localizedDescription)")
//            } else {
//                print("Message sent successfully!")
//            }
//        }
//    }
//
//    // Receive messages from WebSocket
//    private func receiveMessage() {
//        webSocketTask?.receive { [weak self] result in
//            guard let self = self else { return }
//            
//            switch result {
//            case .success(let message):
//                switch message {
//                case .string(let text):
//                    print("Received text message: \(text)")
//                    DispatchQueue.main.async {
//                        self.onMessageReceived?(text)  // Notify the received message to the UI
//                    }
//                case .data(let data):
//                    print("Received binary message: \(data)")
//                    self.handleBinaryData(data)
//                @unknown default:
//                    fatalError("Received unknown message type")
//                }
//            case .failure(let error):
//                print("Failed to receive message: \(error.localizedDescription)")
//                DispatchQueue.main.async {
//                    self.onConnectionChange?(false)  // Notify connection failure
//                }
//            }
//
//            // Continue listening for more messages
//            self.receiveMessage()
//        }
//    }
//    
//    // Inside WebSocketManager.swift
//    private func handleBinaryData(_ data: Data) {
//        // Step 1: Extract the metadata length (first 4 bytes)
//        guard data.count >= 4 else {
//            print("Error: Data is too short to contain metadata length")
//            return
//        }
//        
//        let metadataLengthRange = 0..<4
//        let metadataLengthData = data.subdata(in: metadataLengthRange)
//        let metadataLength = metadataLengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
//        let totalMetadataLength = 4 + Int(metadataLength)
//        print(data.count, Int(metadataLength))
//        guard data.count >= totalMetadataLength else {
//            print("Error: Data is too short to contain the full metadata")
//            return
//        }
//        
//        // Step 2: Extract the metadata based on the length
//        let metadataRange = 4..<(4 + Int(metadataLength))
//        let metadataData = data.subdata(in: metadataRange)
//        if let metadataString = String(data: metadataData, encoding: .utf8),
//           let jsonData = metadataString.data(using: .utf8) {
//            do {
//                // Try to decode the metadata JSON
//                let decodedMetadata = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
//                print("Received metadata: \(String(describing: decodedMetadata))")
//                
//                // Step 3: Extract the binary file data (the rest of the data)
//                let fileData = data.subdata(in: (4 + Int(metadataLength))..<data.count)
//                print("Received binary file data of size: \(fileData.count) bytes")
//                
//                // Pass both metadata and file data to the UI or further processing
//                DispatchQueue.main.async {
//                    self.onAudioReceived?(fileData, decodedMetadata ?? [:])
//                }
//                
//            } catch {
//                print("Failed to parse metadata JSON: \(error.localizedDescription)")
//            }
//        } else {
//            print("Failed to decode metadata string")
//        }
//    }
//
//    // Disconnect the WebSocket
//    func disconnect() {
//        webSocketTask?.cancel(with: .goingAway, reason: nil)
//        print("WebSocket disconnected.")
//        onConnectionChange?(false)  // Notify disconnection
//    }
//}
//
//extension WebSocketManager: URLSessionWebSocketDelegate {
//    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
//        print("WebSocket closed with code: \(closeCode)")
//        onConnectionChange?(false)  // Notify that the connection is closed
//    }
//
//    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
//        print("WebSocket connection established.")
//        onConnectionChange?(true)  // Notify that the connection is open
//    }
//}

