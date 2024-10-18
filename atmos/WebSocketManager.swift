//
//  WebSocketManager.swift
//  atmos
//
//  Created by Tom Joy on 17/10/2024.
//

import Foundation

class WebSocketManager: NSObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    
    // Closure to notify connection status change
    var onConnectionChange: ((Bool) -> Void)?

    override init() {
        super.init()
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }

    func connect(to url: URL) {
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessage()
    }

    func send(message: String) {
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("Failed to send message: \(error.localizedDescription)")
            } else {
                print("Message sent successfully!")
            }
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    print("Received text message: \(text)")
                case .data(let data):
                    print("Received binary message: \(data)")
                @unknown default:
                    fatalError("Received unknown message type")
                }
            case .failure(let error):
                print("Failed to receive message: \(error.localizedDescription)")
            }

            // Continue listening for more messages
            self?.receiveMessage()
        }
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
}

extension WebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket closed with code: \(closeCode)")
        onConnectionChange?(false)  // Notify that the connection is closed
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("WebSocket connection established.")
        onConnectionChange?(true)  // Notify that the connection is open
    }
}

