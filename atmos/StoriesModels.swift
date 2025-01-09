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
    let arc_section: Int
}

class StoriesStore: ObservableObject {
    @Published var stories: [Document] = []
    @Published var selectedStoryTitle: String? = nil
    private let networkingManager = NetworkingManager() // Instance of NetworkingManager

    // Helper to get the full Document based on the selected story title
    var selectedStory: Document? {
        stories.first(where: { $0.story_name == selectedStoryTitle })
    }

    // Method to fetch stories from the server
    func fetchDocuments(completion: ((Error?) -> Void)? = nil) {
        networkingManager.fetchStoriesPayload { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let payload):
                    // Assign the fetched stories to the local `stories` property
                    self?.stories = payload.stories
                    completion?(nil) // Success, no error
                case .failure(let error):
                    completion?(error) // Pass the error to the caller
                }
            }
        }
    }
}
