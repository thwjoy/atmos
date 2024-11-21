//import Foundation
//import AVFoundation
//import Foundation
//
//class WebSocketManager: NSObject {
//    private var webSocketTask: URLSessionWebSocketTask?
//    private let audioEngine = AVAudioEngine()
//    private var isStreaming = false
//    private let audioProcessingQueue = DispatchQueue(label: "AudioProcessingQueue")
//    private var accumulatedAudio = Data() // Accumulate audio chunks
//    private var expectedAudioSize = 0     // Expected total size of the audio
//    private var sampleRate = 44100        // Default sample rate, updated by header
//    private let HEADER_SIZE = 13
//    private let processingQueue = DispatchQueue(label: "com.websocket.audioProcessingQueue")
//    var onConnectionChange: ((Bool) -> Void)? // Called when connection status changes
//    var onMessageReceived: ((String) -> Void)? // Called for received text messages
//    var onAudioReceived: ((Data, Bool) -> Void)? // Called for received audio
//    var stopRecordingCallback: (() -> Void)?
//
//    // Connect to the WebSocket server
//    func connect(to url: URL) {
//        disconnect() // Ensure any existing connection is closed
//        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
//        webSocketTask = session.webSocketTask(with: url)
//        webSocketTask?.resume()
//        receiveMessages()
//    }
//
//    func disconnect() {
//        webSocketTask?.cancel(with: .normalClosure, reason: "Client closing connection".data(using: .utf8))
//        webSocketTask = nil
//        stopAudioStream()
//        onConnectionChange?(false)
//        stopRecordingCallback?()
//        // Clear the accumulatedAudio buffer
//        self.processingQueue.async {
//            self.accumulatedAudio = Data()
//            print("Accumulated audio buffer cleared")
//        }
//    }
//
//    // Start streaming audio
//    func sendAudioStream() {
//        guard !isStreaming else { return }
//        isStreaming = true
//
//        let inputNode = audioEngine.inputNode
//        let hardwareFormat = inputNode.inputFormat(forBus: 0)
//
//        inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { [weak self] buffer, _ in
//            guard let self = self else { return }
//            self.audioProcessingQueue.async {
//                if let audioData = self.convertPCMBufferToData(buffer: buffer) {
//                    self.sendData(audioData)
//                } else {
//                    print("Failed to convert audio buffer to data")
//                }
//            }
//        }
//        
//        do {
//            try audioEngine.start()
//            print("Audio engine started")
//        } catch {
//            print("Failed to start audio engine: \(error.localizedDescription)")
//        }
//    }
//
//    // Stop streaming audio
//    func stopAudioStream() {
//        isStreaming = false
//        audioEngine.inputNode.removeTap(onBus: 0)
//        audioEngine.stop()
//    }
//
//    // Convert PCM buffer to data
//    private func convertPCMBufferToData(buffer: AVAudioPCMBuffer) -> Data? {
//        if let int16ChannelData = buffer.int16ChannelData {
//            // Use Int16 data directly
//            let channelData = int16ChannelData[0]
//            let frameLength = Int(buffer.frameLength)
//            return Data(bytes: channelData, count: frameLength * MemoryLayout<Int16>.size)
//        } else if let floatChannelData = buffer.floatChannelData {
//            // Convert Float32 to Int16
//            let channelData = Array(UnsafeBufferPointer(start: floatChannelData[0], count: Int(buffer.frameLength)))
//            let int16Data = channelData.map { Int16($0 * Float(Int16.max)) }
//            return Data(bytes: int16Data, count: int16Data.count * MemoryLayout<Int16>.size)
//        } else {
//            print("Unsupported audio format")
//            return nil
//        }
//    }
//
//    // Send binary data via WebSocket
//    private func sendData(_ data: Data) {
//        let message = URLSessionWebSocketTask.Message.data(data)
//        webSocketTask?.send(message) { error in
//            if let error = error {
//                print("Failed to send data: \(error.localizedDescription)")
//            }
//        }
//    }
//
//    private func receiveMessages() {
//        webSocketTask?.receive { [weak self] result in
//            guard let self = self else { return }
//
//            switch result {
//            case .success(let message):
//                switch message {
//                case .data(let data):
//                    self.processReceivedData(data)
//                case .string(let text):
//                    self.onMessageReceived?(text)
//                @unknown default:
//                    print("Unknown WebSocket message type")
//                }
//
//                // Continue listening for messages
//                self.receiveMessages()
//
//            case .failure(let error):
//                print("Failed to receive message: \(error.localizedDescription)")
//
//                // Stop recursion and handle disconnect
//                self.disconnect()
//            }
//        }
//    }
//    
//    private func extractUInt32(from data: Data, at range: Range<Data.Index>) -> UInt32 {
//        let subdata = data.subdata(in: range) // Extract the range
//        return subdata.withUnsafeBytes { $0.load(as: UInt32.self) } // Safely load UInt32
//    }
//    
//    private func parseWAVHeader(data: Data) -> (sampleRate: Int, channels: Int, bitsPerSample: Int)? {
//        guard data.count >= 44 else {
//            print("Invalid WAV file: Header too short")
//            return nil
//        }
//
//        // Verify the "RIFF" chunk ID
//        let chunkID = String(bytes: data[0..<4], encoding: .ascii)
//        guard chunkID == "RIFF" else {
//            print("Invalid WAV file: Missing RIFF header")
//            return nil
//        }
//
//        // Verify the "WAVE" format
//        let format = String(bytes: data[8..<12], encoding: .ascii)
//        guard format == "WAVE" else {
//            print("Invalid WAV file: Missing WAVE format")
//            return nil
//        }
//
//        // Parse sample rate
//        let sampleRate = data.subdata(in: 24..<28).withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
//
//        // Parse number of channels
//        let channels = data.subdata(in: 22..<24).withUnsafeBytes { $0.load(as: UInt16.self) }.littleEndian
//
//        // Parse bits per sample
//        let bitsPerSample = data.subdata(in: 34..<36).withUnsafeBytes { $0.load(as: UInt16.self) }.littleEndian
//
//        return (sampleRate: Int(sampleRate), channels: Int(channels), bitsPerSample: Int(bitsPerSample))
//    }
//    
//
//    private func processReceivedData(_ data: Data) {
//        processingQueue.async { [weak self] in
//            guard let self = self else { return }
//            
//            // Check if this chunk is SFX (always check first)
//            if data.count >= self.HEADER_SIZE {
//                let headerData = data.prefix(self.HEADER_SIZE)
//                let indicator = String(bytes: headerData[0..<5], encoding: .utf8)?.trimmingCharacters(in: .whitespaces) ?? "UNKNOWN"
//                print(indicator)
//                if indicator == "SFX" {
//                    // Sound effect (SFX), play immediately
//                    print("Recieved SFX")
//                    let sfxData = data.suffix(from: self.HEADER_SIZE + 44)
//                    DispatchQueue.main.async {
//                        self.onAudioReceived?(sfxData, true)
//                    }
//                    return // Stop further processing for this chunk
//                }
//            }
//
//            // Handle background music
//            if self.accumulatedAudio.isEmpty {
//                // First chunk of background music
//                if data.count >= self.HEADER_SIZE {
//                    let headerData = data.prefix(self.HEADER_SIZE)
//                    let indicator = String(bytes: headerData[0..<5], encoding: .utf8) ?? "UNKNOWN"
//
//                    if indicator == "MUSIC" {
//                        // Parse header and start accumulating audio
//                        self.expectedAudioSize = Int(self.extractUInt32(from: headerData, at: 5..<9).bigEndian)
//                        self.sampleRate = Int(self.extractUInt32(from: headerData, at: 9..<13).bigEndian)
//                        print("Indicator: \(indicator), Expected Size: \(self.expectedAudioSize), Sample Rate: \(self.sampleRate)")
//
//                        // Parse WAV header
//                        let wavHeaderData = data.subdata(in: self.HEADER_SIZE..<(44 + self.HEADER_SIZE))
//                        if let wavInfo = self.parseWAVHeader(data: wavHeaderData) {
//                            let sampleRate = Int(wavInfo.sampleRate)
//                            let channels = wavInfo.channels
//                            let bitsPerSample = wavInfo.bitsPerSample
//
//                            print("Parsed WAV Info: Sample Rate = \(sampleRate), Channels = \(channels), Bits Per Sample = \(bitsPerSample)")
//
//                            // Start accumulating data after the WAV header
//                            self.accumulatedAudio.append(data.suffix(from: 44 + self.HEADER_SIZE))
//                        }
//                    } else {
//                        print("Error: Unknown audio type in header")
//                    }
//                } else {
//                    print("Error: Incomplete header")
//                }
//            } else {
//                // Subsequent chunks for background music
//                self.accumulatedAudio.append(data)
//
//                // Process accumulated audio in chunks
//                let chunkSize = 2048 // Adjust as needed
//                while self.accumulatedAudio.count >= chunkSize {
//                    let chunk = self.accumulatedAudio.prefix(chunkSize)
//                    self.accumulatedAudio.removeFirst(chunkSize)
//                    DispatchQueue.main.async {
//                        self.onAudioReceived?(chunk, false)
//                    }
//                }
//            }
//        }
//    }
//}
//
//extension WebSocketManager: URLSessionWebSocketDelegate {
//    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
//        print("WebSocket connected")
//        onConnectionChange?(true) // Confirm the connection
//    }
//
//    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
//        print("WebSocket disconnected with code: \(closeCode.rawValue)")
//        if let reason = reason, let reasonString = String(data: reason, encoding: .utf8) {
//            print("Reason: \(reasonString)")
//        }
//        onConnectionChange?(false) // Confirm the disconnection
//    }
//}
