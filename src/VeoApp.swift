import SwiftUI

@main
struct VeoApp: App {
	var body: some Scene {
		WindowGroup {
			ContentView()
		}
	}
}

struct List: Decodable, Encodable, Identifiable, Equatable {
    let id: UUID
    let user_id: UUID
    var name: String
    let created_at: String
}

struct Item: Decodable, Encodable, Identifiable, Equatable {
    let id: UUID
    let user_id: UUID
    let list_id: UUID
    var done: Bool
    var text: String
    var index: Int
}