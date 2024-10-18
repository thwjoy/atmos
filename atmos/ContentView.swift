//
//  ContentView.swift
//  atmos
//
//  Created by Tom Joy on 17/10/2024.
//

import SwiftUI
import AVFoundation
import Foundation

func uploadAudioForTranscription(audioURL: URL, apiKey: String, completion: @escaping (String?) -> Void) {
    // Create the request URL for OpenAI's Whisper API
    let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

    // Prepare the request
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

    // Define boundary string for multipart form data
    let boundary = UUID().uuidString
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    // Create multipart form data
    var body = Data()

    // Add audio file to the request body
    let audioData = try! Data(contentsOf: audioURL)
    let fileName = audioURL.lastPathComponent

    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
    body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
    body.append(audioData)
    body.append("\r\n".data(using: .utf8)!)

    // Add "model" parameter
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
    body.append("whisper-1\r\n".data(using: .utf8)!)

    // Close the multipart form data
    body.append("--\(boundary)--\r\n".data(using: .utf8)!)

    // Add body to the request
    request.httpBody = body

    // Create a URLSession task to send the request
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        // Handle any errors
        if let error = error {
            print("Error: \(error.localizedDescription)")
            completion(nil)
            return
        }

        // Check for valid response and data
        guard let data = data, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("Invalid response or data")
            completion(nil)
            return
        }

        // Parse the response JSON
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let text = json["text"] as? String {
            completion(text) // Return the transcribed text
        } else {
            completion(nil)
        }
    }

    // Start the task
    task.resume()
}

struct ContentView: View {
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var transcriptionText: String = ""
    @State private var connectionStatus: String = "Not connected"
    @State private var messageStatus: String = ""
    
    private var webSocketManager = WebSocketManager()  // Initialize WebSocketManager

    var body: some View {
        VStack(spacing: 20) {
            Text(isRecording ? "Recording..." : "Tap to Record")
                .font(.largeTitle)
                .padding()

            Button(action: {
                if self.isRecording {
                    self.stopRecording()
                } else {
                    self.startRecording()
                }
            }) {
                Text(isRecording ? "Stop Recording" : "Start Recording")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .background(isRecording ? Color.red : Color.green)
                    .cornerRadius(10)
            }

            Text(transcriptionText)
                .padding()
                .font(.body)

            VStack(alignment: .leading) {
                Text("Connection Status: \(connectionStatus)")
                    .foregroundColor(connectionStatus == "Connected" ? .green : .red)
                    .font(.headline)

                Text("Message Status: \(messageStatus)")
                    .font(.subheadline)
                    .foregroundColor(messageStatus.contains("Sent") ? .green : .gray)
            }
            .padding(.top, 20)
        }
        .padding()
        .onAppear {
            // Connect to the WebSocket when the view appears
            if let url = URL(string: "ws://localhost:5001") {
                webSocketManager.connect(to: url)
                connectionStatus = "Connecting..."  // Indicate that connection is in progress
            }

            // Update connection status based on WebSocket events
            webSocketManager.onConnectionChange = { status in
                DispatchQueue.main.async {
                    self.connectionStatus = status ? "Connected" : "Disconnected"
                }
            }
        }
        .onDisappear {
            // Disconnect from the WebSocket when the view disappears
            webSocketManager.disconnect()
            connectionStatus = "Disconnected"
        }
    }

    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)

            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let audioFileURL = getDocumentsDirectory().appendingPathComponent("recording.m4a")

            audioRecorder = try AVAudioRecorder(url: audioFileURL, settings: settings)
            audioRecorder?.record()

            isRecording = true
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false

        if let url = audioRecorder?.url {
            uploadAudioForTranscription(audioURL: url, apiKey: "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") { transcription in
                if let transcription = transcription {
                    DispatchQueue.main.async {
                        self.transcriptionText = transcription
                        webSocketManager.send(message: transcription)
                        self.messageStatus = "Message sent!"
                    }
                } else {
                    print("Failed to transcribe audio")
                    self.messageStatus = "Failed to send message"
                }
            }
        }
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}



#Preview {
    ContentView()
}
