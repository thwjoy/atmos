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
    
    @Binding var selectedTab: AppTabView.Tab

    var body: some View {
        NavigationView {
            ZStack {
                Image("Spark_background") // Force the background directly in NavigationView
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .opacity(0.5)

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
                        List {
                            ForEach(storiesStore.stories, id: \.id) { document in
                                HStack {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(document.story_name)
                                            .font(.headline)
                                        Text(document.story)
                                            .font(.subheadline)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Menu {
                                        Button(action: {
                                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                               let rootViewController = scene.windows.first?.rootViewController {
                                                shareStory(
                                                    from: rootViewController,
                                                    storyName: document.story_name,
                                                    storyContent: document.story
                                                )
                                            }
                                        }) {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }
                                        
                                        Button(action: {
                                            selectedStory = document // Set the selected story
                                        }) {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        
                                        Button(action: {
                                            playAndConnect(document: document)
                                        }) {
                                            Label("Play", systemImage: "play.circle")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.vertical, 5)
                            }
                        }
                        .scrollContentBackground(.hidden) // Hides the List's default background
                        .background(Color.clear) // Ensures List background is transparent
                    }
                }
                .navigationTitle("Documents")
                .sheet(item: $selectedStory) { story in
                    StoryEditorView(story: Binding(
                        get: { story },
                        set: { newStory in
                            // Update the story in the store
                            if let index = storiesStore.stories.firstIndex(where: { $0.id == newStory.id }) {
                                storiesStore.stories[index] = newStory
                            }
                        }
                    ))
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

    func shareStory(from viewController: UIViewController,
                    storyName: String,
                    storyContent: String) {
        let storyText = """
        Check out this I made with Spark!:

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
        viewController.present(activityViewController, animated: true, completion: nil)
    }
}


