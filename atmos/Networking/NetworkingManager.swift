//
//  NetworkingManager.swift
//  Spark
//
//  Created by Tom Joy on 09/01/2025.
//

import Foundation

let STORIES_URL = "https://myatmos.pro/stories"

/// A class to manage network requests
class NetworkingManager {
    
    /// Performs a login request to authenticate the user.
    /// - Parameters:
    ///   - email: The user's email to authenticate.
    ///   - completion: A closure that returns a `Result` with a success status or error message.
    func performLoginRequest(email: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        // Flask API URL
        guard let url = URL(string: "\(STORIES_URL)/login") else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        // Prepare JSON request
        let json: [String: Any] = ["contact_email": email]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json) else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare request data."])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        // Send the request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error)) // Pass the network error
                return
            }

            guard let data = data, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid server response."])))
                return
            }

            if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let success = jsonResponse["success"] as? Bool {
                if success {
                    completion(.success(true))
                } else {
                    let errorMessage = jsonResponse["error"] as? String ?? "An unknown error occurred."
                    completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                }
            } else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse server response."])))
            }
        }.resume()
    }
    
    func updateStoryOnServer(
        storyID: String,
        updatedName: String,
        updatedContent: String,
        arcSection: Int,
        isVisible: Bool,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard let url = URL(string: "\(STORIES_URL)/\(storyID)") else {
            completion(false, "Invalid URL.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        let username = UserDefaults.standard.string(forKey: "userName") ?? ""
        request.addValue(username, forHTTPHeaderField: "username")
        request.addValue("Bearer \(TOKEN)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "story_name": updatedName,
            "story": updatedContent,
            "arc_section": arcSection,
            "visible": isVisible
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(false, "Failed to encode story data.")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, "Network error: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(false, "Server error: Failed to update story.")
                return
            }

            completion(true, nil) // Success
        }.resume()
    }
    
    func fetchStreak(completion: @escaping (Result<Int, Error>) -> Void) {
        // Retrieve the email (username) from UserDefaults
        guard let username = UserDefaults.standard.string(forKey: "userName"), !username.isEmpty else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Username not set in UserDefaults."])))
            return
        }

        // Flask API URL
        guard let url = URL(string: "\(STORIES_URL)/streak") else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        // Set up the request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(username, forHTTPHeaderField: "username") // Add the username in the headers

        // Send the request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error)) // Pass the network error
                return
            }

            guard let data = data, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid server response."])))
                return
            }

            // Parse the response
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let streakValue = json["streak"] as? Int {
                completion(.success(streakValue))
            } else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format."])))
            }
        }.resume()
    }
    
    func updateStreakRequest(points: Int, completion: @escaping (Result<Int, Error>) -> Void) {
        // Retrieve the email (username) from UserDefaults
        let username = UserDefaults.standard.string(forKey: "userName") ?? ""

        guard !username.isEmpty else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Username not set in UserDefaults."])))
            return
        }

        guard let url = URL(string: "\(STORIES_URL)/streak") else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        // Set up the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(username, forHTTPHeaderField: "username")  // Add the username in the headers

        // Prepare the JSON payload
        let payload: [String: Any] = [
            "points": points
        ]

        // Convert the payload to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize JSON payload."])))
            return
        }

        request.httpBody = jsonData

        // Perform the network request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error)) // Pass the network error
                return
            }

            guard let data = data, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid server response."])))
                return
            }

            // Parse the response
            if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let success = jsonResponse["success"] as? Bool, success {
                if let updatedStreak = jsonResponse["streak"] as? Int {
                    completion(.success(updatedStreak)) // Return the updated streak
                } else {
                    completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Streak value missing in response."])))
                }
            } else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format."])))
            }
        }.resume()
    }
    
    // Fetch stories payload from the server
    func fetchStoriesPayload(completion: @escaping (Result<DocumentPayload, Error>) -> Void) {
        guard let url = URL(string: "\(STORIES_URL)/get_stories") else {
            completion(.failure(NSError(domain: "Invalid URL", code: 400, userInfo: [NSLocalizedDescriptionKey: "The URL provided is invalid."])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let username = UserDefaults.standard.string(forKey: "userName") ?? ""
        guard !username.isEmpty else {
            completion(.failure(NSError(domain: "Username not set", code: 401, userInfo: [NSLocalizedDescriptionKey: "Username not set in UserDefaults."])))
            return
        }

        request.addValue(username, forHTTPHeaderField: "username")
        request.addValue("Bearer \(TOKEN)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error)) // Network error
                return
            }

            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                completion(.failure(NSError(domain: "Server error", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch stories."])))
                return
            }

            do {
                // Decode the payload into `DocumentPayload`
                let decodedPayload = try JSONDecoder().decode(DocumentPayload.self, from: data)
                completion(.success(decodedPayload))
            } catch {
                completion(.failure(error)) // Decoding error
            }
        }.resume()
    }
    
    func fetchCharacters(completion: @escaping (Result<[Character], Error>) -> Void) {
        guard let username = UserDefaults.standard.string(forKey: "userName"), !username.isEmpty else {
            completion(.failure(NSError(domain: "Username not set", code: 401, userInfo: [NSLocalizedDescriptionKey: "Username not set in UserDefaults."])))
            return
        }

        guard var urlComponents = URLComponents(string: "\(STORIES_URL)/characters") else {
            completion(.failure(NSError(domain: "Invalid URL", code: 400, userInfo: [NSLocalizedDescriptionKey: "The URL provided is invalid."])))
            return
        }

        // Add query parameters
        urlComponents.queryItems = [
            URLQueryItem(name: "owner_id", value: username),
            URLQueryItem(name: "visible_only", value: "true")
        ]

        guard let url = urlComponents.url else {
            completion(.failure(NSError(domain: "Invalid URL", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to construct URL."])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error)) // Network error
                return
            }

            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                completion(.failure(NSError(domain: "Server error", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch characters."])))
                return
            }

            do {
                // Decode the JSON response into an array of `Character`
                let characters = try JSONDecoder().decode([Character].self, from: data)
                completion(.success(characters))
            } catch {
                completion(.failure(error)) // Decoding error
            }
        }.resume()
    }
    
    func saveCharacter(
            id: String,
            name: String,
            description: String,
            ownerID: String,
            visible: Bool = true,
            completion: @escaping (Result<Void, Error>) -> Void
        ) {
            guard let url = URL(string: "\(STORIES_URL)/characters") else {
                completion(.failure(NSError(domain: "Invalid URL", code: 400, userInfo: [NSLocalizedDescriptionKey: "The URL provided is invalid."])))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let characterData: [String: Any] = [
                "id": id,
                "name": name,
                "description": description,
                "owner_id": ownerID,
                "visible": visible
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: characterData) else {
                completion(.failure(NSError(domain: "Serialization Error", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize character data."])))
                return
            }

            request.httpBody = jsonData

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error)) // Network error
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
                    completion(.failure(NSError(domain: "Server error", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to save the character."])))
                    return
                }

                completion(.success(())) // Success
            }.resume()
        }
    
    func deleteCharacter(id: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Construct the URL
        guard let url = URL(string: "\(STORIES_URL)/characters/\(id)") else {
            completion(.failure(NSError(domain: "Invalid URL", code: 400, userInfo: nil)))
            return
        }

        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Prepare the JSON body
        let body: [String: Any] = ["visible": 0]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        // Start the URL session task
        URLSession.shared.dataTask(with: request) { _, response, error in
            // Check for error
            if let error = error {
                completion(.failure(error))
                return
            }

            // Check for valid HTTP response status code
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let statusError = NSError(
                    domain: "Invalid Response",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to update character visibility. HTTP Status: \(httpResponse.statusCode)"]
                )
                completion(.failure(statusError))
                return
            }

            // Success
            completion(.success(()))
        }.resume()
    }
}

