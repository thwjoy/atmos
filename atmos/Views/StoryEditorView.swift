//
//  StoryEditorView.swift
//  Spark
//
//  Created by Tom Joy on 23/12/2024.
//

import Foundation
import Combine
import SwiftUI

private func blobColorForArcState(_ arcState: Int) -> Color { // TODO move this to file
    switch arcState {
    case 0:
        return .gray // Default state
    case 1: // Stasis
        return Color(red: 157/255.0, green: 248/255.0, blue: 239/255.0) // #9df8ef
    case 2: // Trigger
        return Color(red: 191/255.0, green: 161/255.0, blue: 237/255.0) // #bfa1ed
    case 3: // The quest
        return Color(red: 255/255.0, green: 198/255.0, blue: 0/255.0) // #ffc600
    case 4: // Surprise
        return Color(red: 248/255.0, green: 96/255.0, blue: 15/255.0) // #f8600f
    case 5: // Critical choice
        return Color(red: 217/255.0, green: 140/255.0, blue: 0/255.0) // #d98c00
    case 6: // Climax
        return Color(red: 255/255.0, green: 75/255.0, blue: 46/255.0) // #ff4b2e
    case 7: // Resolution
        return Color(red: 255/255.0, green: 218/255.0, blue: 185/255.0) // #ffdab9
    default:
        return .gray // Default fallback color
    }
}

struct StoryEditorView: View {
    @Binding var story: Document
    @Environment(\.dismiss) var dismiss // To close the sheet
    @EnvironmentObject var storiesStore: StoriesStore

    @State private var updatedStoryName: String
    @State private var updatedStoryContent: String
    @State private var isSaving = false // Loading indicator for saving
    @State private var errorMessage: String? // Error message, if any
    @State private var showDeleteConfirmation = false // State for showing delete confirmation
    private let networkingManager = NetworkingManager() // Instance of NetworkingManager

    // Callbacks for the menu actions
    var onShare: (String, String) -> Void
    var onPlayAndConnect: (Document) -> Void
    var onEdit: (Document) -> Void

    init(
        story: Binding<Document>,
        onShare: @escaping (String, String) -> Void,
        onPlayAndConnect: @escaping (Document) -> Void,
        onEdit: @escaping (Document) -> Void
    ) {
        _story = story
        _updatedStoryName = State(initialValue: story.wrappedValue.story_name)
        _updatedStoryContent = State(initialValue: story.wrappedValue.story)
        self.onShare = onShare
        self.onPlayAndConnect = onPlayAndConnect
        self.onEdit = onEdit
    }

    var body: some View {
        VStack {
//            TextField("Story Title", text: $updatedStoryName)
//                .textFieldStyle(RoundedBorderTextFieldStyle())
//                .padding()
//
//            TextEditor(text: $updatedStoryContent)
//                .padding()
//                .border(Color.gray, width: 1)
//                .cornerRadius(8)
//                .frame(maxHeight: .infinity)
            
            // Display the story title as non-editable text
            Text(updatedStoryName)
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ProgressBar(currentProgress: story.arc_section,
                        colorForArcState: blobColorForArcState)
            
            // Display the story content as non-editable text
            ScrollView {
                Text(updatedStoryContent)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .border(Color.gray, width: 1)
                    .cornerRadius(8)
            }
            .frame(maxHeight: .infinity)

            if isSaving {
                ProgressView("Saving...")
                    .padding()
            } else if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            }
            
            Text(story.arc_section == 7 ? "Share your story to recieve 100 coins" : "Recieve 100 coins for finishing and sharing your story")
                .foregroundColor(story.arc_section == 7 ? .blue : .gray) // Gray when "disabled"
                .italic() // Makes the text italic

            HStack(spacing: 20) {
                // Delete Button
                Button(action: {
                    showDeleteConfirmation = true // Show the confirmation alert
                }) {
                    HStack {
                        Image(systemName: "trash")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50) // Set a fixed height for the button
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                // Share Button
                Button(action: {
                    onShare(story.story_name, story.story)
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50) // Set a fixed height for the button
                    .background(story.arc_section == 7 ? Color.blue : Color.gray) // Change color based on enabled/disabled state
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .opacity(story.arc_section == 7 ? 1.0 : 0.5) // Reduce opacity when disabled
                }
                .disabled(story.arc_section != 7) // Disable when arc_section is not 7

                // Continue Button
                Button(action: {
                    onPlayAndConnect(story)
                }) {
                    HStack {
                        Image(systemName: "play.circle")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50) // Set a fixed height for the button
                    .background(story.arc_section != 7 ? Color.green : Color.gray) // Change color based on enabled/disabled state
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .opacity(story.arc_section != 7 ? 1.0 : 0.5) // Reduce opacity when disabled
                }
                .disabled(story.arc_section == 7) // Disable when arc_section is 7

                // Save Button
//                Button(action: saveChanges) {
//                    HStack {
//                        Image(systemName: "square.and.pencil")
//                    }
//                    .font(.headline)
//                    .frame(maxWidth: .infinity)
//                    .frame(height: 50) // Set a fixed height for the button
//                    .background(Color.orange)
//                    .foregroundColor(.white)
//                    .cornerRadius(10)
//                }
            }
            .padding()
        }
        .padding()
        .navigationTitle("Edit Story")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showDeleteConfirmation) { // Add alert modifier
            Alert(
                title: Text("Confirm Deletion"),
                message: Text("Are you sure you want to delete this story? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteStory() // Call delete function if confirmed
                },
                secondaryButton: .cancel()
            )
        }
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
        networkingManager.updateStoryOnServer(
            storyID: story.id,
            updatedName: updatedStoryName,
            updatedContent: updatedStoryContent,
            arcSection: story.arc_section,
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
        print("Deleting")
        networkingManager.updateStoryOnServer(
            storyID: story.id,
            updatedName: story.story_name,
            updatedContent: story.story,
            arcSection: story.arc_section,
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
}
