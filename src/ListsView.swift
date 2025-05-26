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
                        if idx < lists.count {
                            Task {
                                await renameList(at: idx, to: newName)
                            }
                        }
                    },
                    onAdd: { name in
                        Task {
                            await addList(name: name)
                        }
                    },
                    onItemTap: { idx in
                        if idx < lists.count {
                            selectedList = lists[idx]
                            UISelectionFeedbackGenerator().selectionChanged()
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
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(1)

                    VeoListView(
                        title: selected.name,
                        items: selected.items.map { $0.text },
                        onRename: { idx, newText in
                            Task {
                                await renameListItem(at: lists.firstIndex(of: selected) ?? 0, itemIndex: idx, to: newText)
                            }
                        },
                        onAdd: { text in
                            Task {
                                await addListItem(at: lists.firstIndex(of: selected) ?? 0, text: text)
                            }
                        },
                        onPinchExit: {
                            withAnimation(.easeOut(duration: 0.18)) { selectedList = nil }
                        },
                        isTopLevel: false
                    )
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
                }
            }
            .animation(.easeInOut(duration: 0.27), value: selectedList)
        }
        .toast(
            message: toastMessage,
            isPresented: .init(
                get: { toastMessage != nil },
                set: { if !$0 { toastMessage = nil } }
            )
        )
        .background(VeoListView.color1)
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
                .order("created_at", ascending: false)
                .execute()
                .value
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

    func addList(name: String) async {
        guard !name.isEmpty else { return }
        do {
            let currentUser = try await supabase.auth.session.user
            let newList = List(
                id: UUID().uuidString,
                user_id: currentUser.id,
                name: name,
                items: [],
                created_at: Date().iso8601String
            )
            lists.insert(newList, at: 0)
            _ = try await supabase
                .from("lists")
                .insert(newList)
                .execute()
        } catch {
            toastMessage = "Add list failed: \(error.localizedDescription)"
            if let index = lists.firstIndex(where: { $0.name == name }) {
                lists.remove(at: index)
            }
        }
    }

    func renameListItem(at listIndex: Int, itemIndex: Int, to newText: String) async {
        guard listIndex < lists.count, itemIndex < lists[listIndex].items.count else { return }
        let oldText = lists[listIndex].items[itemIndex].text
        lists[listIndex].items[itemIndex].text = newText
        do {
            if let selected = selectedList, selected.id == lists[listIndex].id {
                selectedList = lists[listIndex]
            }
            _ = try await supabase
                .from("lists")
                .update(["items": lists[listIndex].items])
                .eq("id", value: lists[listIndex].id)
                .execute()
        } catch {
            lists[listIndex].items[itemIndex].text = oldText
            toastMessage = "Rename item failed: \(error.localizedDescription)"
        }
    }

    func addListItem(at listIndex: Int, text: String) async {
        guard listIndex < lists.count, !text.isEmpty else { return }
        let newItem = Item(id: UUID(), done: false, text: text)
        lists[listIndex].items.insert(newItem, at: 0)
        do {
            if let selected = selectedList, selected.id == lists[listIndex].id {
                selectedList = lists[listIndex]
            }
            _ = try await supabase
                .from("lists")
                .update(["items": lists[listIndex].items])
                .eq("id", value: lists[listIndex].id)
                .execute()
        } catch {
            lists[listIndex].items.remove(at: 0)
            toastMessage = "Add item failed: \(error.localizedDescription)"
        }
    }
}

struct List: Decodable, Encodable, Identifiable, Equatable {
    let id: String
    let user_id: UUID
    var name: String
    var items: [Item]
    let created_at: String
}

struct Item: Decodable, Encodable, Identifiable, Equatable {
    var id: UUID
    var done: Bool
    var text: String

    // Custom decoding to handle missing id
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        done = try container.decode(Bool.self, forKey: .done)
        text = try container.decode(String.self, forKey: .text)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
    }

    // Custom encoding to always include id
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(done, forKey: .done)
        try container.encode(text, forKey: .text)
        try container.encode(id, forKey: .id)
    }

    // For manual creation
    init(id: UUID = UUID(), done: Bool, text: String) {
        self.id = id
        self.done = done
        self.text = text
    }

    private enum CodingKeys: String, CodingKey {
        case id, done, text
    }
}