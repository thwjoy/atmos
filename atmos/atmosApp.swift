//
//  atmosApp.swift
//  atmos
//
//  Created by Tom Joy on 17/10/2024.
//

import SwiftUI
import AVFoundation

@main
struct atmosApp: App {
    init() {
        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Set category to playback to override silent mode
            try audioSession.setCategory(AVAudioSession.Category.playback)
            // Activate the session
            try audioSession.setActive(true)
            print("Audio session configured to override silent mode.")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
}
