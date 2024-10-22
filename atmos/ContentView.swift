//
//  ContentView.swift
//  atmos
//
//  Created by Tom Joy on 17/10/2024.
//

import SwiftUI
import AVFoundation
import Foundation

var OPENAI_API_KEY  = "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"
var SERVER_URL = "ws://localhost:5001"

func uploadAudioForTranscription(audioURL: URL, apiKey: String, completion: @escaping (String?) -> Void) {
    print("Starting audio transcription upload...")
    
    // Create the request URL for OpenAI's Whisper API
    let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    
    // Prepare the request
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    print("API Key added to request")

    // Define boundary string for multipart form data
    let boundary = UUID().uuidString
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    // Create multipart form data
    var body = Data()

    do {
        // Add audio file to the request body
        let audioData = try Data(contentsOf: audioURL)
        let fileName = audioURL.lastPathComponent
        print("Audio file data loaded, filename: \(fileName)")

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
        print("Request body successfully constructed")

    } catch {
        print("Error loading audio file data: \(error.localizedDescription)")
        completion(nil)
        return
    }

    // Log request headers and body size
    print("Request Headers: \(String(describing: request.allHTTPHeaderFields))")
    print("Request Body Size: \(body.count) bytes")

    // Create a URLSession task to send the request
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        // Handle any errors
        if let error = error {
            print("Error occurred during the request: \(error.localizedDescription)")
            completion(nil)
            return
        }

        // Check for valid response and data
        if let httpResponse = response as? HTTPURLResponse {
            print("Received response: HTTP \(httpResponse.statusCode)")
        }

        guard let data = data, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("Invalid response or data")
            completion(nil)
            return
        }

        // Log the raw response data (optional for debugging)
        print("Raw response data: \(String(data: data, encoding: .utf8) ?? "N/A")")

        // Parse the response JSON
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            print("Parsed response JSON: \(json)")
            if let text = json["text"] as? String {
                print("Transcription successful: \(text)")
                completion(text) // Return the transcribed text
            } else {
                print("No transcription text found in the response")
                completion(nil)
            }
        } else {
            print("Failed to parse JSON from response")
            completion(nil)
        }
    }

    // Start the task
    print("Sending transcription request...")
    task.resume()
}


struct ContentView: View {
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var transcriptionText: String = ""
    @State private var connectionStatus: String = "Not connected"
    @State private var messageStatus: String = ""
    @State private var messages: [String] = []  // List to store sent/received messages
    @State private var isAutomaticRecordingActive = false  // Tracks if automatic recording is active
    @State private var timer: Timer?  // Timer for automatic recording
    @State private var typedMessage: String = "Harry lay in his dark cupboard much later, wishing he had a watch. He didn’t know what time it was"  // For user-typed messages
    
    private var webSocketManager = WebSocketManager()  // Initialize WebSocketManager

    var body: some View {
        VStack(spacing: 20) {
//            Text(isRecording ? "Recording..." : "Idle")
//                .font(.title)
//                .foregroundColor(isRecording ? .red : .green)

            Button(action: {
                if self.isAutomaticRecordingActive {
//                    self.stopAutomaticRecording()
                    self.stopRecording()
                    isRecording = false
//                    isAutomaticRecordingActive = false
                    print("Stopped Automatic Recording")
                } else {
                    self.startRecording()
                    isRecording = true
//                    self.startAutomaticRecording()
//                    isAutomaticRecordingActive = true
                    print("Started Automatic Recording")
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
                Text("Recording Status: \(isRecording ? "Recording..." : "Idle")")
                    .foregroundColor(isRecording == true ? .green : .red)
                    .font(.headline)
                
                Text("Connection Status: \(connectionStatus)")
                    .foregroundColor(connectionStatus == "Connected" ? .green : .red)
                    .font(.headline)

                Text("Message Status: \(messageStatus)")
                    .font(.subheadline)
                    .foregroundColor(messageStatus.contains("Sent") ? .green : .gray)
            }
            .padding(.top, 20)

            // Text field for typing messages
            TextField("Type a message", text: $typedMessage)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            // Button to send the typed message
            Button(action: {
                if !typedMessage.isEmpty {
                    webSocketManager.send(message: typedMessage)
                    messages.append("Sent: \(typedMessage)")  // Log sent message
                    typedMessage = ""  // Clear the input field after sending
                    messageStatus = "Message sent!"
                }
            }) {
                Text("Send Message")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .disabled(typedMessage.isEmpty)  // Disable button if text field is empty
            
            // Display messages sent/received in a list
            VStack(alignment: .leading) {
                Text("Messages Log")
                    .font(.headline)
                    .padding(.bottom, 5)

                ScrollView {
                    ForEach(messages, id: \.self) { message in
                        Text(message)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                message.hasPrefix("Sent:") ? Color.gray.opacity(0.2) :
                                message.hasPrefix("Received:") ? Color.blue.opacity(0.2) : Color.clear
                            )
                            .cornerRadius(5)
                    }
                }
                .frame(height: 200)
                .border(Color.gray, width: 1)
            }
            .padding(.top, 20)
        }
        .padding()
        .onAppear {
            // Connect to the WebSocket when the view appears
            if let url = URL(string: SERVER_URL) {
                webSocketManager.connect(to: url)
                connectionStatus = "Connecting..."
            }

            // Update connection status based on WebSocket events
            webSocketManager.onConnectionChange = { status in
                DispatchQueue.main.async {
                    self.connectionStatus = status ? "Connected" : "Disconnected"
                }
            }

            // Handle incoming messages
            webSocketManager.onMessageReceived = { message in
                DispatchQueue.main.async {
                    self.messages.append("Received: \(message)")
                }
            }
            
            // Handle audio and metadata received
            webSocketManager.onAudioReceived = { audioData, metadata in
                DispatchQueue.main.async {
                // Append metadata to the messages log
                    let metadataDescription = metadata.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
                    self.messages.append("Received: \(metadataDescription)")
                }
            }
            
        }
        .onDisappear {
            // Disconnect from the WebSocket and stop the timer when the view disappears
            webSocketManager.disconnect()
            stopAutomaticRecording()
            connectionStatus = "Disconnected"
        }
    }

    // Start a 5-second timer for automatic recording
    func startAutomaticRecording() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in

            // If currently recording, stop recording
            if self.isRecording {
                self.stopRecording()

                // Pause for 50 milliseconds before starting recording again
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.startRecording()
                }
            } else {
                // Start recording if not already recording
                self.startRecording()
            }
        }
    }

    // Stop the automatic recording timer
    func stopAutomaticRecording() {
        timer?.invalidate()
        timer = nil
    }

    // Start the audio recording
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
            print("Recording started")
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }

    // Stop the audio recording and send transcription
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false

        if let url = audioRecorder?.url {
            uploadAudioForTranscription(audioURL: url, apiKey: OPENAI_API_KEY) { transcription in
                if let transcription = transcription {
                    DispatchQueue.main.async {
                        self.transcriptionText = transcription
                        self.webSocketManager.send(message: transcription)
                        self.messageStatus = "Message sent!"
                        self.messages.append("Sent: \(transcription)")  // Log sent message
                    }
                } else {
                    print("Failed to transcribe audio")
                    self.messageStatus = "Failed to send message"
                }
            }
        }
    }

    // Get the directory for saving the audio file
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}


#Preview {
    ContentView()
}
