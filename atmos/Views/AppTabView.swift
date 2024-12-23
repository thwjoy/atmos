//
//  File.swift
//  Spark
//
//  Created by Tom Joy on 23/12/2024.
//

import Foundation
import Combine
import SwiftUI


struct AppTabView: View {
    @State private var selectedTab: Tab = .spark

    enum Tab {
        case spark, stories
    }
    

    var body: some View {
        TabView(selection: $selectedTab) {
            MainView()
                .tabItem {
                    Label("Spark", systemImage: "house")
                }
                .tag(Tab.spark)

            StoriesView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Stories", systemImage: "doc.text")
                }
                .tag(Tab.stories)
        }
    }
}
