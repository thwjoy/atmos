//
//  WebSocketManager.swift
//  Spark
//
//  Created by Tom Joy on 23/12/2024.
//

import Foundation


class WebSocketManager: NSObject, ObservableObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionWebSocketDelegate {
    private var webSocketTask: URLSessionWebSocketTask?
    private let audioProcessor: AudioProcessor // Use dependency injection
//    private var isStreaming = false
//    private var isConnected = false // Track connection state
    private let recieveQueue = DispatchQueue(label: "com.websocket.recieveQueue")
    struct AudioSequence {
        var indicator: String       // Indicator (e.g., "MUSIC" or "SFX")
        var accumulatedData: Data  // Accumulated audio data
        var packetsReceived: Int    // Number of packets received
        var sampleRate: Double
    }
    private var accumulatedAudio: [UUID: AudioSequence] = [:]
//    private var expectedAudioSize = 0     // Expected total size of the audio
    private let HEADER_SIZE = 37
    private var sessionID: String? = nil
//    private let maxAudioSize = 50 * 1024 * 1024 // 50MB in bytes

    var onAppStateChange: ((AppAudioState) -> Void)?
    var onARCStateChange: ((Int) -> Void)?
    var onStreakChange: ((Int) -> Void)?
    var onMessageReceived: ((String) -> Void)? // Called for received text messages
    var onAudioReceived: ((Data, String, Double) -> Void)? // Called for received audio
    var audioDownloading: ((Bool) -> Void)?
//    var stopRecordingCallback: (() -> Void)?
    
    init(audioProcessor: AudioProcessor) {
        self.audioProcessor = audioProcessor
    }

    func connect(to url: URL, token: String, coAuthEnabled: Bool, musicEnabled: Bool, SFXEnabled: Bool, story_id: String) {
        stopAudioStream()
        disconnect() // Ensure any existing connection is closed

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(coAuthEnabled ? "True" : "False", forHTTPHeaderField: "CO-AUTH")
        request.setValue(musicEnabled ? "True" : "False", forHTTPHeaderField: "MUSIC")
        request.setValue(SFXEnabled ? "True" : "False", forHTTPHeaderField: "SFX")
        let username = UserDefaults.standard.string(forKey: "userName")
        request.setValue(username, forHTTPHeaderField: "userName")
        request.setValue(story_id, forHTTPHeaderField: "storyId")
        print("Sending UUID \(story_id)")
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        receiveMessages()
    }


    
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: "Client closing connection".data(using: .utf8))
        webSocketTask = nil
        sessionID = ""
        // Clear the accumulatedAudio buffer
        self.recieveQueue.async {
            self.accumulatedAudio = [:]
            print("Accumulated audio buffer cleared")
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("WebSocket connected")
        DispatchQueue.main.async { [weak self] in
            self?.onAppStateChange?(.idle)
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket disconnected with code: \(closeCode.rawValue)")
        if let reason = reason, let reasonString = String(data: reason, encoding: .utf8) {
            print("Reason: \(reasonString)")
        }
        DispatchQueue.main.async { [weak self] in
            self?.onAppStateChange?(.disconnected)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("WebSocket connection failed with error: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.onAppStateChange?(.disconnected)
            }
        }
    }

    func sendAudioStream() {
//        guard !isStreaming else { return } TODO
        onAppStateChange?(.recording)
        print("Streaming Audio")

        audioProcessor.configureInputTap(bufferSize: 1024) { [weak self] buffer in
            guard let self = self else { return }
            if let audioData = self.audioProcessor.convertPCMBufferToData(buffer: buffer) {
                self.sendData(audioData)
            } else {
                print("Failed to convert audio buffer to data")
            }
        }
        audioProcessor.startAudioEngine()
    }

    func stopAudioStream() {
        audioProcessor.removeTap()
    }
        
    func processSessionUpdate(sessionID: String?) {
        if let uuidString = sessionID, UUID(uuidString: uuidString) != nil {
            // sessionID is a valid UUID
            DispatchQueue.main.async { [weak self] in
                self?.onAppStateChange?(.listening)
            }
        } else {
            // sessionID is not valid
            DispatchQueue.main.async { [weak self] in
                self?.onAppStateChange?(.idle)
            }
        }
    }

    // Send binary data via WebSocket
    private func sendData(_ data: Data) {
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("Failed to send data: \(error.localizedDescription)")
            }
        }
    }
    
    func sendTextMessage(_ text: String) {
        let message = URLSessionWebSocketTask.Message.string(text)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("Failed to send text message: \(error.localizedDescription)")
            } else {
                print("Text message sent: \(text)")
            }
        }
    }

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.processReceivedData(data)
                case .string(let text):
                    self.processRecievedMessage(text: text)
                @unknown default:
                    print("Unknown WebSocket message type")
                }

                // Continue listening for messages
                self.receiveMessages()

            case .failure(let error):
                print("Failed to receive message: \(error.localizedDescription)")

                // Stop recursion and handle disconnect
                self.disconnect()
            }
        }
    }
    
    private func processRecievedMessage(text: String) {
        DispatchQueue.main.async {
            // here we need to check that streaming is enabled
            if UUID(uuidString: text) != nil {
                self.sessionID = text
            }
            // 2) Check if the string has "ARCNO: " prefix
            else if text.hasPrefix("ARCNO: ") {
                // Remove the "ARCNO: " part
                let numberString = text.replacingOccurrences(of: "ARCNO: ", with: "")
                
                // Attempt to convert it to an Int
                if let arcNumber = Int(numberString) {
                    DispatchQueue.main.async { [weak self] in
                        self?.onARCStateChange?(arcNumber)
                    }
                } else {
                    // The substring after "ARCNO: " wasn't a valid Int
                    print("Invalid ARCNO format: \(numberString)")
                }
            }
            // 3) Otherwise handle other messages from server
            else if text.hasPrefix("Streak: ") {
                // Remove the "ARCNO: " part
                let numberString = text.replacingOccurrences(of: "Streak: ", with: "")
                
                // Attempt to convert it to an Int
                if let arcNumber = Int(numberString) {
                    DispatchQueue.main.async { [weak self] in
                        self?.onStreakChange?(arcNumber)
                    }
                } else {
                    // The substring after "ARCNO: " wasn't a valid Int
                    print("Invalid Streak format: \(numberString)")
                }
            }
        }
    }
    
    private func extractUInt32(from data: Data, at range: Range<Data.Index>) -> UInt32 {
        let subdata = data.subdata(in: range) // Extract the range
        return subdata.withUnsafeBytes { $0.load(as: UInt32.self) } // Safely load UInt32
    }
    
    private func processReceivedData(_ data: Data) {
        recieveQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Ensure we have enough data for the header
            guard data.count >= self.HEADER_SIZE else {
                print("Error: Incomplete header")
                return
            }
            
            // Parse the header
            let headerData = data.prefix(self.HEADER_SIZE)
            let indicator = String(bytes: headerData[0..<5], encoding: .utf8)?.trimmingCharacters(in: .whitespaces) ?? "UNKNOWN"
            let packetSize = Int(self.extractUInt32(from: headerData, at: 5..<9).bigEndian)
            let sequenceID = UUID(uuid: (headerData[9..<25] as NSData).bytes.assumingMemoryBound(to: uuid_t.self).pointee)
            let packetCount = Int(self.extractUInt32(from: headerData, at: 25..<29).bigEndian)
            let totalPackets = Int(self.extractUInt32(from: headerData, at: 29..<33).bigEndian)
            let sampleRate = Double(self.extractUInt32(from: headerData, at: 33..<37).bigEndian)
            
            print("Indicator: \(indicator), Sequence ID: \(sequenceID), Packet: \(packetCount)/\(totalPackets), Sample Rate: \(sampleRate), Packet Size: \(packetSize)")
            
            // If this is a new STORY sequence, clear the previously stored story audio.
            if indicator == "STORY" && self.accumulatedAudio[sequenceID] == nil {
                DispatchQueue.main.async {
                    self.audioProcessor.previousStoryAudio.removeAll()
                    print("Cleared previous story")
                }
            }
            
            // Process based on the indicator
            if self.accumulatedAudio[sequenceID] == nil {
                // First packet for this sequence
                self.accumulatedAudio[sequenceID] = AudioSequence(
                    indicator: indicator,
                    accumulatedData: Data(),
                    packetsReceived: 0,
                    sampleRate: sampleRate
                )
                // start indicator that audio is downloading, stop recording
                
                DispatchQueue.main.async {
                    self.audioDownloading?(true)
                }
            }
            
            // Update the existing entry
            if var sequence = self.accumulatedAudio[sequenceID] {
                sequence.accumulatedData.append(data.suffix(from: self.HEADER_SIZE))
                sequence.packetsReceived += 1
                self.accumulatedAudio[sequenceID] = sequence
                print("Updated Sequence \(sequenceID): Packets Received = \(sequence.packetsReceived)")
                let chunkSize = 2048 // Adjust as needed
                if sequence.packetsReceived * data.count >= 1024 * 32 { //only start when 128kb
                    while sequence.accumulatedData.count >= chunkSize {
                        let chunk = sequence.accumulatedData.prefix(chunkSize)
                        sequence.accumulatedData.removeFirst(chunkSize)
                        // Reassign the modified value back to the dictionary
                        self.accumulatedAudio[sequenceID] = sequence
                        if sequence.indicator == "STORY"{
                            DispatchQueue.main.async {
                                self.onAppStateChange?(.playing)
                            }
                        }
                        if sequence.indicator == "FILL" {
                            //                        DispatchQueue.main.async {
                            //                            self.onAppStateChange?(.thinking)
                            //                            self.onAudioReceived?(chunk, "STORY", sequence.sampleRate)
                            //                        }
                        } else {
                            DispatchQueue.main.async {
                                self.onAudioReceived?(chunk, sequence.indicator, sequence.sampleRate)
                            }
                        }
                        
                    }
                }
                if sequence.packetsReceived == totalPackets  {
                    print("Received complete sequence for \(sequence.indicator) with ID \(sequenceID)")
                    self.accumulatedAudio.removeValue(forKey: sequenceID)
                    
                    DispatchQueue.main.async {
                        self.audioDownloading?(false)
                    }
                }
            }
            
        }
    }
}
