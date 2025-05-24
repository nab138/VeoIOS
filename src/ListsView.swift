import SwiftUI

struct ListsView: View {
    @State var lists: [List] = []
    @State private var toastMessage: String? = nil
    @State private var selectedList: List? = nil
    @Namespace private var animation

    var body: some View {
        NavigationStack {
            ZStack {
                VeoListView(
                    title: "Veo Lists",
                    items: lists.map { $0.name } + ["Sign Out"],
                    onRename: { idx, newName in
                        if idx < lists.count { // Prevent renaming Sign Out
                            Task {
                                await renameList(at: idx, to: newName)
                            }
                        }
                    },
                    onItemTap: { idx in
                        if idx < lists.count {
                            selectedList = lists[idx]
                            return
                        }
                        let action = idx - lists.count
                        if action == 0 {
                            Task {
                                do {
                                    try await supabase.auth.signOut()
                                } catch {
                                    toastMessage = "Sign out failed: \(error.localizedDescription)"
                                }
                            }
                        }
                    },
                    isTopLevel: true,
                    nonRenamableIndices: [lists.count]
                )
                if let selected = selectedList {
                    VeoListView(
                        title: selected.name,
                        items: selected.items.map { $0.text },
                        onPinchExit: {
                            withAnimation(.easeOut(duration: 0.18)) { selectedList = nil }
                        },
                        isTopLevel: false // Not top-level
                    )
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
                }
            }
            .animation(.easeOut(duration: 0.18), value: selectedList)
        }
        .toast(
            message: toastMessage,
            isPresented: .init(
                get: { toastMessage != nil },
                set: { if !$0 { toastMessage = nil } }
            )
        )
        .task {
            await getLists()
        }
    }

    func getLists() async {
        do {
            let currentUser = try await supabase.auth.session.user
            lists = try await supabase
                .from("lists")
                .select()
                .eq("user_id", value: currentUser.id)
                .execute()
                .value
        } catch let decodingError as DecodingError {
            // Show more detailed decoding error
            switch decodingError {
            case .typeMismatch(let type, let context):
                toastMessage = "Type mismatch: \(type) - \(context.debugDescription)"
            case .valueNotFound(let type, let context):
                toastMessage = "Value not found: \(type) - \(context.debugDescription)"
            case .keyNotFound(let key, let context):
                toastMessage = "Key '\(key.stringValue)' not found: \(context.debugDescription)"
            case .dataCorrupted(let context):
                toastMessage = "Data corrupted: \(context.debugDescription)"
            @unknown default:
                toastMessage = "Unknown decoding error"
            }
        } catch {
            toastMessage = "Error: \(error.localizedDescription)"
        }
    }

    func renameList(at idx: Int, to newName: String) async {
        guard idx < lists.count else { return }
        let oldName = lists[idx].name
        lists[idx].name = newName // Optimistically update
        do {
            _ = try await supabase
                .from("lists")
                .update(["name": newName])
                .eq("id", value: lists[idx].id)
                .execute()
        } catch {
            lists[idx].name = oldName // Revert if failed
            toastMessage = "Rename failed: \(error.localizedDescription)"
        }
    }
}

struct List: Decodable, Identifiable, Equatable {
    let id: String
    let user_id: String
    var name: String // changed from let to var
    let items: [Item]
    let created_at: String
}

struct Item: Decodable, Equatable {
    let done: Bool
    let text: String
}