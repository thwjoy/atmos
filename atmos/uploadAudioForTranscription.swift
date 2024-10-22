//
//  uploadAudioForTranscription.swift
//  atmos
//
//  Created by Tom Joy on 22/10/2024.
//

import Foundation

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
