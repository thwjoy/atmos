//
//  TextEntryView.swift
//  Spark
//
//  Created by Tom Joy on 23/12/2024.
//

import Foundation
import SwiftUI

struct LoginView: View {
    @State private var inputText: String = ""
    @Binding var isUserNameSet: Bool
    @State private var errorMessage: String? = nil
    private let networkingManager = NetworkingManager() // Instance of NetworkingManager

    var body: some View {
        ZStack {

            Color(red: 1.0, green: 0.956, blue: 0.956) // #fff4f4
                .ignoresSafeArea() // Ensures the color covers the entire screen
            
            VStack(spacing: 20) {
                Text("Enter your email to proceed")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                TextField("", text: $inputText)
                    .padding(10)              // Add padding inside the text field
                    .background(Color.white)  // Set background color to white
                    .foregroundColor(.gray)
                    .cornerRadius(5)          // Optional: Rounded edges
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1) // Add a subtle border
                    )
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                Button(action: {
                    if isValidEmail(inputText) {
                        authenticateUser(email: inputText)
                    } else {
                        errorMessage = "Please enter a valid email address."
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
                .disabled(inputText.isEmpty)
                .padding(.horizontal)
            }
            .padding()
        }
    }

    func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPredicate.evaluate(with: email)
    }

    func authenticateUser(email: String) { //TODO look at this
        networkingManager.performLoginRequest(email: email) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Save email to UserDefaults and update state
                    UserDefaults.standard.set(email, forKey: "userName")
                    isUserNameSet = true
                case .failure(let error):
                    // Use the error's localized description for the message
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
