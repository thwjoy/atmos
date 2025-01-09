//
//  DocumentsView.swift
//  Spark
//
//  Created by Tom Joy on 23/12/2024.
//

import Foundation
import Combine
import SwiftUI

import SwiftUI

struct CircularProgressBar: View {
    let currentProgress: Int // Current progress value (dynamic)
    let colorForArcState: (Int) -> Color // Function to get the color for each state
    let totalSections: Int = 7 // Total sections in the circle

    var body: some View {
        ZStack {
            // Background circle (gray sections)
            ForEach(0..<totalSections, id: \.self) { index in
                CircleSegment(
                    startAngle: startAngle(for: index),
                    endAngle: endAngle(for: index)
                )
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
            }

            // Filled segments based on progress
            ForEach(0..<currentProgress, id: \.self) { index in
                CircleSegment(
                    startAngle: startAngle(for: index),
                    endAngle: endAngle(for: index)
                )
                .stroke(
                    currentProgress == totalSections ? Color.green : colorForArcState(index + 1), // All green if progress is max
                    lineWidth: 8
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // Helper functions to calculate angles for each segment
    private func startAngle(for index: Int) -> Angle {
        return Angle(degrees: (Double(index) / Double(totalSections)) * 360.0 - 90.0)
    }

    private func endAngle(for index: Int) -> Angle {
        return Angle(degrees: (Double(index + 1) / Double(totalSections)) * 360.0 - 90.0)
    }
}

// Custom shape for drawing circular segments
struct CircleSegment: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}



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
                Color(red: 1.0, green: 0.956, blue: 0.956) // #fff4f4
                    .ignoresSafeArea() // Ensures the color covers the entire screen
                
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
                                                colorForArcState: { index in
                                                    switch index {
                                                    case 1: return Color(red: 157/255.0, green: 248/255.0, blue: 239/255.0) // #9df8ef
                                                    case 2: return Color(red: 191/255.0, green: 161/255.0, blue: 237/255.0) // #bfa1ed
                                                    case 3: return Color(red: 255/255.0, green: 198/255.0, blue: 0/255.0) // #ffc600
                                                    case 4: return Color(red: 248/255.0, green: 96/255.0, blue: 15/255.0) // #f8600f
                                                    case 5: return Color(red: 217/255.0, green: 140/255.0, blue: 0/255.0) // #d98c00
                                                    case 6: return Color(red: 255/255.0, green: 75/255.0, blue: 46/255.0) // #ff4b2e
                                                    case 7: return Color(red: 255/255.0, green: 218/255.0, blue: 185/255.0) // #ffdab9
                                                    default: return Color.gray
                                                    }
                                                }
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


