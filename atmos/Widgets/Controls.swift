//
//  Controls.swift
//  Spark
//
//  Created by Tom Joy on 09/01/2025.
//

import Foundation
import SwiftUI

struct ProgressBar: View { // TODO
    let currentProgress: Int
    let colorForArcState: (Int) -> Color // Function to get the color for a specific arcState

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<7) { index in
                Rectangle()
                    .fill(currentProgress == 7 ? Color.green : // All bars green if progress is full
                        (index < currentProgress ? colorForArcState(index + 1) : Color.gray.opacity(0.4))) // Use normal logic otherwise
                    .frame(width: 30, height: 10)
                    .cornerRadius(2)
            }
        }
        .padding(.top)
    }
}

func blobColorForArcState(_ arcState: Int) -> Color { // TODO
    switch arcState {
    case 0:
        return .gray // Default state
    case 1: // Stasis
        return Color(red: 157/255.0, green: 248/255.0, blue: 239/255.0) // #9df8ef
    case 2: // Trigger
        return Color(red: 191/255.0, green: 161/255.0, blue: 237/255.0) // #bfa1ed
    case 3: // The quest
        return Color(red: 255/255.0, green: 198/255.0, blue: 0/255.0) // #ffc600
    case 4: // Surprise
        return Color(red: 248/255.0, green: 96/255.0, blue: 15/255.0) // #f8600f
    case 5: // Critical choice
        return Color(red: 217/255.0, green: 140/255.0, blue: 0/255.0) // #d98c00
    case 6: // Climax
        return Color(red: 255/255.0, green: 75/255.0, blue: 46/255.0) // #ff4b2e
    case 7: // Resolution
        return Color(red: 255/255.0, green: 218/255.0, blue: 185/255.0) // #ffdab9
    default:
        return .gray // Default fallback color
    }
}

struct CircularProgressBar: View {
    let currentProgress: Int // Current progress value (dynamic)
    let colorForArcState: (Int) -> Color // Function to get the color for each state
    let totalSections: Int = 7 // Total sections in the circle

    var body: some View {
        ZStack {
            // Background circle (gray sections)
            ForEach(0..<totalSections, id: \.self) { index in
                CircleSegment(
                    startAngle: startAngle(for: index),
                    endAngle: endAngle(for: index)
                )
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
            }

            // Filled segments based on progress
            ForEach(0..<currentProgress, id: \.self) { index in
                CircleSegment(
                    startAngle: startAngle(for: index),
                    endAngle: endAngle(for: index)
                )
                .stroke(
                    currentProgress == totalSections ? Color.green : colorForArcState(index + 1), // All green if progress is max
                    lineWidth: 8
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // Helper functions to calculate angles for each segment
    private func startAngle(for index: Int) -> Angle {
        return Angle(degrees: (Double(index) / Double(totalSections)) * 360.0 - 90.0)
    }

    private func endAngle(for index: Int) -> Angle {
        return Angle(degrees: (Double(index + 1) / Double(totalSections)) * 360.0 - 90.0)
    }
}

// Custom shape for drawing circular segments
struct CircleSegment: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

struct BackgroundImage: View {
    var body: some View {
//        Image("Spark_background")
//            .resizable()
//            .scaledToFill()
//            .ignoresSafeArea()
//            .opacity(0.5)
        Color(red: 1.0, green: 0.956, blue: 0.956) // #fff4f4
            .ignoresSafeArea() // Ensures the color covers the entire screen
    }
}

struct ControlButtons: View {
    let replayStoryAudio: () -> Void
    let disconnect: () -> Void
    @Binding var showDisconnectConfirmation: Bool

    var body: some View {
        HStack {
            // Replay Button
            Button(action: replayStoryAudio) {
                CircleButton(iconName: "gobackward", backgroundColor: .blue)
            }

            Spacer()

            // Disconnect Button with Confirmation
            Button(action: {
                showDisconnectConfirmation = true
            }) {
                CircleButton(iconName: "xmark", backgroundColor: .red)
            }
            .alert(isPresented: $showDisconnectConfirmation) {
                Alert(
                    title: Text("Disconnect?"),
                    message: Text("Are you sure you want to disconnect? This will stop the current session. Your story will be availabe to resume and share in a few minutes."),
                    primaryButton: .destructive(Text("Disconnect")) {
                        disconnect() // Perform the disconnect action
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .padding(.horizontal, 50)
    }
}


struct CircleButton: View {
    let iconName: String
    let backgroundColor: Color

    var body: some View {
        Image(systemName: iconName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 50, height: 50)
            .padding()
            .background(backgroundColor)
            .foregroundColor(.white)
            .clipShape(Circle())
            .shadow(radius: 5)
    }
}

struct StoryPicker: View {
    @EnvironmentObject var storiesStore: StoriesStore

    var body: some View {
        Picker("Select Story", selection: $storiesStore.selectedStoryTitle) {
            Text("Make a New Story").tag(nil as String?)

            // Filter stories where arc_section != 7
            ForEach(storiesStore.stories.filter { $0.arc_section != 7 }, id: \.story_name) { story in
                Text(story.story_name).tag(story.story_name as String?)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .foregroundColor(.black)
        .shadow(radius: 5)
    }
}


struct StartConnectionButton: View {
    var connect: () -> Void // Action to perform when the button is tapped

    var body: some View {
        Button(action: {
            connect()
        }) {
            Text("Start")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green)
                .cornerRadius(10)
                .shadow(radius: 5)
        }
        .padding(.horizontal, 50) // Add horizontal padding
    }
}


struct MusicToggle: View {
    @Binding var isOn: Bool // Binding to control the toggle's state
    var disconnect: () -> Void // Action to perform when the toggle changes

    var body: some View {
        Toggle(isOn: $isOn) {
            Text("How about adding some music?")
                .font(.headline)
                .foregroundColor(.gray)
        }
        .onChange(of: isOn) { newValue, _ in
            // Perform any cleanup if needed when the toggle changes
            if !newValue {
                disconnect()
            }
        }
        .padding(30) // Add padding
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10) // Round the corners
    }
}


struct MicrophoneButton: View {
    @Binding var appAudioState: AppAudioState
    let onGestureChange: () -> Void
    let onGestureEnd: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(1.0),
                            connectionColor.opacity(0.8)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    connectionColor.opacity(0.8),
                                    connectionColor,
                                    connectionColor.opacity(0.8)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 5
                        )
                )
                .shadow(color: connectionColor.opacity(0.5), radius: 10, x: 5, y: 5)
                .shadow(color: connectionColor.opacity(0.8), radius: 10, x: -5, y: -5)
                .frame(width: 150, height: 150)

            Image(systemName: connectionButton)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(connectionColor)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onGestureChange() }
                .onEnded { _ in onGestureEnd() }
        )
    }

    private var connectionColor: Color {
        switch appAudioState {
        case .disconnected: return .red
        case .connecting: return .orange
        case .idle: return .yellow
        case .listening, .recording: return .green
        case .thinking, .playing: return .yellow
        }
    }

    private var connectionButton: String {
        switch appAudioState {
        case .disconnected, .connecting, .idle, .listening, .thinking, .playing:
            return "mic.slash.fill"
        case .recording:
            return "mic.fill"
        }
    }
}

