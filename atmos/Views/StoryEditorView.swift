//
//  StoryEditorView.swift
//  Spark
//
//  Created by Tom Joy on 23/12/2024.
//

import Foundation
import Combine
import SwiftUI

struct StoryEditorView: View {
    @Binding var story: Document
    @Environment(\.dismiss) var dismiss // To close the sheet
    @EnvironmentObject var storiesStore: StoriesStore

    @State private var updatedStoryName: String
    @State private var updatedStoryContent: String
    @State private var isSaving = false // Loading indicator for saving
    @State private var errorMessage: String? // Error message, if any


    init(story: Binding<Document>) {
        _story = story
        _updatedStoryName = State(initialValue: story.wrappedValue.story_name)
        _updatedStoryContent = State(initialValue: story.wrappedValue.story)
    }

    var body: some View {
        VStack {
            TextField("Story Title", text: $updatedStoryName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            TextEditor(text: $updatedStoryContent)
                .padding()
                .border(Color.gray, width: 1)
                .cornerRadius(8)
                .frame(maxHeight: .infinity)

            if isSaving {
                ProgressView("Saving...")
                    .padding()
            } else if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            }

            Button(action: saveChanges) {
                Text("Save Changes")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button(action: deleteStory) {
                Text("Delete Story")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .navigationTitle("Edit Story")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func saveChanges() {
        guard !updatedStoryName.isEmpty else {
            errorMessage = "Story title cannot be empty."
            return
        }
        guard !updatedStoryContent.isEmpty else {
            errorMessage = "Story content cannot be empty."
            return
        }

        isSaving = true
        errorMessage = nil

        // Update the local story object
        story.story_name = updatedStoryName
        story.story = updatedStoryContent

        // Send the updated story to the server
        updateStoryOnServer(
            storyID: story.id,
            updatedName: updatedStoryName,
            updatedContent: updatedStoryContent,
            isVisible: story.visible
        ) { success, error in
            DispatchQueue.main.async {
                isSaving = false

                if success {
                    storiesStore.fetchDocuments { fetchError in
                        if let fetchError = fetchError {
                            errorMessage = "Failed to refresh stories: \(fetchError.localizedDescription)"
                        }
                    }
                    dismiss() // Close the editor on success
                } else {
                    errorMessage = error ?? "Failed to save story. Please try again."
                }
            }
        }
    }
    
    private func deleteStory() {
        errorMessage = nil

        updateStoryOnServer(
            storyID: story.id,
            updatedName: story.story_name,
            updatedContent: story.story,
            isVisible: false // Set visibility to 0
        ) { success, error in
            DispatchQueue.main.async {

                if success {
                    storiesStore.fetchDocuments { fetchError in
                        if let fetchError = fetchError {
                            errorMessage = "Failed to refresh stories: \(fetchError.localizedDescription)"
                        }
                    }
                    dismiss() // Close the editor on success
                } else {
                    errorMessage = error ?? "Failed to delete story. Please try again."
                }
            }
        }
    }

    private func updateStoryOnServer(
        storyID: String,
        updatedName: String,
        updatedContent: String,
        isVisible: Bool,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard let url = URL(string: "https://myatmos.pro/stories/\(storyID)") else {
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
}
