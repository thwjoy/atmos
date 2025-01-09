//
//  DocumentsView.swift
//  Spark
//
//  Created by Tom Joy on 23/12/2024.
//

import Foundation
import Combine
import SwiftUI


struct StoriesView: View {
    @EnvironmentObject var storiesStore: StoriesStore
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedStory: Document? // Holds the currently selected story for editing
    private let networkingManager = NetworkingManager() // Instance of NetworkingManager
    
    @Binding var selectedTab: AppTabView.Tab
    
    var body: some View {
        NavigationView {
            ZStack {
                BackgroundImage()
                
                Group {
                    if isLoading {
                        ProgressView("Fetching documents...")
                    } else if let errorMessage = errorMessage {
                        VStack {
                            Text("Error: \(errorMessage)")
                                .foregroundColor(.red)
                            Button("Retry") {
                                storiesStore.fetchDocuments()
                            }
                            .padding()
                        }
                    } else {
                        ZStack {
                            Color.clear // Transparent background behind the List
                            List {
                                // Sort stories by `arc_section` before rendering
                                ForEach(storiesStore.stories.sorted(by: { $0.arc_section < $1.arc_section }), id: \.id) { document in
                                    NavigationLink(destination: StoryEditorView(
                                        story: Binding(
                                            get: { document },
                                            set: { updatedStory in
                                                if let index = storiesStore.stories.firstIndex(where: { $0.id == updatedStory.id }) {
                                                    storiesStore.stories[index] = updatedStory
                                                }
                                            }
                                        ),
                                        onShare: { name, content in
                                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                               let rootViewController = scene.windows.first?.rootViewController {
                                                shareStory(
                                                    from: rootViewController,
                                                    storyName: name,
                                                    storyContent: content
                                                )
                                            }
                                        },
                                        onPlayAndConnect: { document in
                                            playAndConnect(document: document)
                                        },
                                        onEdit: { document in
                                            selectedStory = document // This will refresh the view
                                        }
                                    )) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 10) {
                                                Text(document.story_name)
                                                    .font(.headline)
                                                Text(String(document.story))
                                                    .font(.subheadline)
                                                    .lineLimit(1)
                                            }
                                            Spacer()

                                            CircularProgressBar(
                                                currentProgress: document.arc_section, // Dynamically set the progress
                                                colorForArcState: blobColorForArcState
                                            )
                                            .frame(width: 50, height: 50) // Adjust size as needed
                                        }
                                        .padding(.vertical, 5)
                                    }
                                }
                            }
                            .scrollContentBackground(.hidden) // Hides the List's default background
                            .background(Color.clear) // Ensures List background is transparent
                        }
                    }
                }
                .onAppear {
                    storiesStore.fetchDocuments()
                }
            }
        }
    }
    // Function to handle play and WebSocket connection
    private func playAndConnect(document: Document) {
        selectedTab = .spark
        storiesStore.selectedStoryTitle = document.story_name
    }
    
    private func updateStreak(points: Int) {
        networkingManager.updateStreakRequest(points: points) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedStreak):
                    print("Streak updated successfully! New streak: \(updatedStreak)")
                    // Update local streak or points if needed
                case .failure(let error):
                    print("Error updating streak: \(error.localizedDescription)")
                }
            }
        }
    }

    func shareStory(from viewController: UIViewController,
                    storyName: String,
                    storyContent: String) {
        let storyText = """
        Check out the story I created with Spark!:

        Title: \(storyName)

        \(storyContent)

        Made with Spark
        https://www.sparkmeapp.com
        """

        let activityViewController = UIActivityViewController(activityItems: [storyText], applicationActivities: nil)
        activityViewController.excludedActivityTypes = [
            .postToFacebook,
            .postToTwitter,
            .postToWeibo,
            .assignToContact,
            .print,
            .saveToCameraRoll
        ]

        // Handle completion of the share action
        activityViewController.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            if completed {
                // Share action was completed successfully
                print("Sharing completed via \(activityType?.rawValue ?? "unknown activity")")
                self.updateStreak(points: 100) // Update the streak points
            } else {
                // Share action was canceled or failed
                if let error = error {
                    print("Error sharing: \(error.localizedDescription)")
                } else {
                    print("Sharing canceled.")
                }
            }
        }

        viewController.present(activityViewController, animated: true, completion: nil)
    }

}


