//
//  TextEntryView.swift
//  Spark
//
//  Created by Tom Joy on 23/12/2024.
//

import Foundation
import SwiftUI

// Email validation function
func isValidEmail(_ email: String) -> Bool {
    let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
    let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    return emailPredicate.evaluate(with: email)
}

struct LoginView: View {
    @State private var inputText: String = ""
    @Binding var isUserNameSet: Bool

    var body: some View {
        ZStack {
            // Set the background image
            Image("Spark_background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea() // Ensures the image fills the screen
                .opacity(0.5) // Adjust the opacity level here
            
            VStack(spacing: 20) {
                Text("Enter your email to proceed")
                    .font(.headline)
                
                TextField("Enter a valid email address", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button(action: {
                    // Usage in your logic
                    if !inputText.isEmpty && isValidEmail(inputText) {
                        // Save the username (email) to UserDefaults
                        UserDefaults.standard.set(inputText, forKey: "userName")
                        // Update state to show main content
                        isUserNameSet = true
                    }
                }) {
                    Text("Save and Continue")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(inputText.isEmpty) // Disable button if text is empty
                .padding(.horizontal)
            }
            .padding()
            
        }
    }
}
