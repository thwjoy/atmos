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

struct ContentView: View {
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var transcriptionText: String = ""
    @State private var connectionStatus: String = "Not connected"
    @State private var messageStatus: String = ""
    @State private var messages: [(String, Data?)] = []  // List to store messages with optional audio data
    @State private var isAutomaticRecordingActive = false  // Tracks if automatic recording is active
    @State private var timer: Timer?  // Timer for automatic recording
    @State private var typedMessage: String = "All rights reserved; no part of this publication may be reproduced or transmitted by any means,"  // For user-typed messages
    @State private var audioPlayer: AVAudioPlayer?  // Add a state for the audio player

    private var webSocketManager = WebSocketManager()  // Initialize WebSocketManager

    var body: some View {
        VStack(spacing: 20) {

            Button(action: {
                if self.isRecording {
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

            // HStack for the TextField and Button in a row
            HStack {
                // Text field for typing messages
                TextField("Type a message", text: $typedMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                // Button to send the typed message
                Button(action: {
                    if !typedMessage.isEmpty {
                        webSocketManager.send(message: typedMessage)
                        messages.append(("Sent: \(typedMessage)", nil))  // Log sent message
                        typedMessage = ""  // Clear the input field after sending
                        messageStatus = "Message sent!"
                    }
                }) {
                    Text("Send")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .disabled(typedMessage.isEmpty)  // Disable button if text field is empty
            }
            .padding()
            
            // Display messages sent/received in a list
            VStack(alignment: .leading) {
                Text("Messages Log")
                    .font(.headline)
                    .padding(.bottom, 5)

                ScrollView {
                    ForEach(messages.indices, id: \.self) { index in
                        let message = messages[index].0
                        let audioData = messages[index].1
                        
                        HStack {
                            Text(message)
                                .padding(.vertical, 5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    message.hasPrefix("Sent:") ? Color.gray.opacity(0.2) :
                                        message.hasPrefix("Received:") ? Color.blue.opacity(0.2) : Color.clear
                                )
                                .cornerRadius(5)
                            
                            // Show play button if there's audio data
                            if let audioData = audioData {
                                Button(action: {
                                    playReceivedAudio(audioData: audioData)
                                }) {
                                    Image(systemName: "play.circle")
                                        .foregroundColor(.blue)
                                        .font(.title2)
                                }
                                .padding(.leading, 10)
                            }
                        }
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
                    self.messages.append(("Received: \(message)", nil))
                }
            }
            
            // Handle audio and metadata received
            webSocketManager.onAudioReceived = { audioData, metadata in
                DispatchQueue.main.async {
                // Append metadata to the messages log
                    let metadataDescription = metadata.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
                    self.messages.append(("Received: \(metadataDescription)", audioData))
                    // Play the received audio data
                    self.playReceivedAudio(audioData: audioData)
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
    
    // Function to play the received audio data
    func playReceivedAudio(audioData: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            print("Playing received audio...")
        } catch {
            print("Error playing audio: \(error.localizedDescription)")
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
                        self.messages.append(("Sent: \(transcription)", nil))  // Log sent message
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
