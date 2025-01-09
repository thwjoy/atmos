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

    func authenticateUser(email: String) {
        // Flask API URL
        guard let url = URL(string: "https://myatmos.pro/stories/login") else { return }
        
        // Prepare JSON request
        let json: [String: Any] = ["contact_email": email]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        // Send the request
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.errorMessage = "Unable to connect to server."
                }
                return
            }

            // Parse response
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let success = jsonResponse["success"] as? Bool, success {
                        DispatchQueue.main.async {
                            // Save email to UserDefaults and navigate
                            UserDefaults.standard.set(email, forKey: "userName")
                            isUserNameSet = true
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.errorMessage = jsonResponse["error"] as? String ?? "An error occurred."
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to authenticate user."
                }
            }
        }.resume()
    }
}
