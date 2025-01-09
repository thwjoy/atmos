//
//  ContentView.swift
//  atmos
//
//  Created by Tom Joy on 17/10/2024.
//

import SwiftUI
import Foundation
import Combine

// var SERVER_URL = "wss://myatmos.pro/test"
var SERVER_URL = "wss://myatmos.pro/ws"
var TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE3MzkwMTExOTUsImlhdCI6MTczNjQxOTE5NSwiaXNzIjoieW91ci1hcHAtbmFtZSJ9.k5WYJKphiTeGTIwIyXtJknqJrQRdlX1KnmzOHgHTTWY"

enum AppAudioState {
    case disconnected   // when not connected to server
    case connecting     // when connecting to server
    case idle           // connected to ws, but transcriber not ready
    case listening      // AI finished talking, waiting for user input
    case recording  // user is currently holding button and speaking
    case thinking     // AI is processing user input
    case playing      // AI is sending audio back
}

struct ContentView: View {
    @State private var isUserNameSet = UserDefaults.standard.string(forKey: "userName") != nil
    @StateObject var storiesStore = StoriesStore()

//    init() {
//        UserDefaults.standard.removeObject(forKey: "userName")
//        print("Username has been cleared for debugging.")
//    }
    
    var body: some View {
        Group {
            if isUserNameSet {
                // Main content of the app, injecting environment object
                AppTabView()
                    .environmentObject(storiesStore)
            } else {
                // Show text entry screen
                LoginView(isUserNameSet: $isUserNameSet)
            }
        }
    }
}



#Preview {
    ContentView()
}
