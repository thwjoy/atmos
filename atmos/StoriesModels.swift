//
//  StoriesModels.swift
//  Spark
//
//  Created by Tom Joy on 23/12/2024.
//

import Foundation
import Combine

struct DocumentPayload: Decodable {
    let stories: [Document]
}

struct Document: Identifiable, Decodable {
    let id: String
    var story: String
    var story_name: String
    let user: String
    let visible: Bool
}

class StoriesStore: ObservableObject {
    @Published var stories: [Document] = []
    @Published var selectedStoryTitle: String? = nil

    // Helper to get the full Document based on the selected story title
    var selectedStory: Document? {
        stories.first(where: { $0.story_name == selectedStoryTitle })
    }

    // Method to fetch stories from the server
    func fetchDocuments(completion: ((Error?) -> Void)? = nil) {
        guard let url = URL(string: "https://myatmos.pro/stories/get_stories") else {
            completion?(NSError(domain: "Invalid URL", code: 400, userInfo: nil))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let username = UserDefaults.standard.string(forKey: "userName") ?? ""
        request.addValue(username, forHTTPHeaderField: "username")
        request.addValue("Bearer \(TOKEN)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion?(error)
                    return
                }
                guard let data = data,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    completion?(NSError(domain: "Failed to fetch documents", code: 500, userInfo: nil))
                    return
                }
                do {
                    let decodedPayload = try JSONDecoder().decode(DocumentPayload.self, from: data)
                    self?.stories = decodedPayload.stories
                    completion?(nil)
                } catch {
                    completion?(error)
                }
            }
        }.resume()
    }
}
