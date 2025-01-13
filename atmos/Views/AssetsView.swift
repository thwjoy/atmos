//
//  CharactersView.swift
//  Spark
//
//  Created by Tom Joy on 23/12/2024.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Character Model
struct Character: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var description: String
}

// MARK: - CharactersStore
class CharactersStore: ObservableObject {
    @Published var characters: [Character] = []
    private let networkingManager = NetworkingManager()

    func fetchCharacters() {
        networkingManager.fetchCharacters { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fetchedCharacters):
                    self?.characters = fetchedCharacters
                case .failure(let error):
                    print("Failed to fetch characters: \(error.localizedDescription)")
                    // Optionally, load characters from SQLite if needed
                }
            }
        }
    }

    func addCharacter(
            name: String,
            description: String,
            completion: @escaping (Result<Void, Error>) -> Void
        ) {
            guard let ownerID = UserDefaults.standard.string(forKey: "userName"), !ownerID.isEmpty else {
                completion(.failure(NSError(domain: "Username not set", code: 401, userInfo: [NSLocalizedDescriptionKey: "Username not set in UserDefaults."])))
                return
            }

            let characterID = UUID().uuidString
            let newCharacter = Character(id: UUID(uuidString: characterID)!, name: name, description: description)

            networkingManager.saveCharacter(
                id: characterID,
                name: name,
                description: description,
                ownerID: ownerID,
                visible: true
            ) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.characters.append(newCharacter)
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
        }

    func deleteCharacter(at offsets: IndexSet) {
        // Get the IDs of the characters to delete
        let idsToDelete = offsets.map { characters[$0].id }
        
        // Remove characters from local array
        characters.remove(atOffsets: offsets)
        
        // Iterate through IDs and delete each character on the backend
        for id in idsToDelete {
            networkingManager.deleteCharacter(id: id.uuidString) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("Character \(id) deleted successfully")
                    case .failure(let error):
                        print("Failed to delete character \(id): \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

struct AssetsView: View {
    @EnvironmentObject var charactersStore: CharactersStore
    @Binding var selectedTab: AppTabView.Tab

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddCharacterView = false
    @State private var newCharacterName = ""
    @State private var newCharacterDescription = ""

    var body: some View {
        NavigationView {
            ZStack {
                BackgroundImage()

                Group {
                    if isLoading {
                        ProgressView("Fetching characters...")
                    } else if let errorMessage = errorMessage {
                        VStack {
                            Text("Error: \(errorMessage)")
                                .foregroundColor(.red)
                            Button("Retry") {
                                charactersStore.fetchCharacters()
                            }
                            .padding()
                        }
                    } else {
                        List {
                            ForEach(charactersStore.characters) { character in
                                NavigationLink(destination: CharacterDetailView(character: character)) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(character.name)
                                            .font(.headline)
                                        Text(character.description)
                                            .font(.subheadline)
                                            .lineLimit(2)
                                    }
                                    .padding(.vertical, 5)
                                }
                            }
                            .onDelete(perform: deleteCharacter)
                        }
                        .listStyle(PlainListStyle())
                        .navigationBarTitle("Characters")
                    }
                }
                .onAppear {
                    charactersStore.fetchCharacters()
                }

                // Plus button at the bottom right
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingAddCharacterView = true
                        }) {
                            Image(systemName: "plus")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                        .sheet(isPresented: $showingAddCharacterView) {
                            VStack {
                                TextField("Character Name", text: $newCharacterName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding()

                                TextField("Character Description", text: $newCharacterDescription)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding()

                                Button("Add Character") {
                                    guard !newCharacterName.isEmpty, !newCharacterDescription.isEmpty else { return }
                                    
                                    charactersStore.addCharacter(name: newCharacterName, description: newCharacterDescription) { result in
                                        switch result {
                                        case .success:
                                            showingAddCharacterView = false
                                            newCharacterName = ""
                                            newCharacterDescription = ""
                                        case .failure(let error):
                                            print("Failed to add character: \(error.localizedDescription)")
                                        }
                                    }
                                }
                                .padding()
                                .buttonStyle(.borderedProminent)
                            }
                            .padding()
                        }
                    }
                }
            }
        }
    }

    private func deleteCharacter(at offsets: IndexSet) {
        charactersStore.deleteCharacter(at: offsets)
    }
}

// MARK: - AddCharacterView
struct AddCharacterView: View {
    @Environment(\.presentationMode) var presentationMode

    @State private var name = ""
    @State private var description = ""

    var onSave: (Character) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Character Details")) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                }
            }
            .navigationBarTitle("New Character", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    let newCharacter = Character(name: name, description: description)
                    onSave(newCharacter)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(name.isEmpty || description.isEmpty)
            )
        }
    }
}

// MARK: - CharacterDetailView
struct CharacterDetailView: View {
    var character: Character
    @EnvironmentObject var charactersStore: CharactersStore
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(character.name)
                .font(.largeTitle)
                .bold()
            Text(character.description)
                .font(.body)
            Spacer()
            
//            Button(action: {
//                if let index = charactersStore.characters.firstIndex(where: { $0.id == character.id }) {
//                    charactersStore.deleteCharacter(at: IndexSet(integer: index))
//                    presentationMode.wrappedValue.dismiss() // Navigate back
//                }
//            }) {
//                Text("Delete Character")
//                    .foregroundColor(.white)
//                    .padding()
//                    .frame(maxWidth: .infinity)
//                    .background(Color.red)
//                    .cornerRadius(8)
//            }
//            .padding(.horizontal)
        }
        .padding()
        .navigationBarTitle(Text(character.name), displayMode: .inline)
    }
}

