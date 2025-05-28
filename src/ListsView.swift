import SwiftUI

struct ListsView: View {
    @State var lists: [List] = []
    @State private var toastMessage: String? = nil
    @State private var selectedList: List? = nil
    @State private var selectedItems: [Item] = []
    @Namespace private var animation

    // Add state for delete confirmation
    @State private var listIndexToDelete: Int? = nil
    @State private var showDeleteConfirmation: Bool = false
    
    // State for undoing item delete
    @State private var lastDeletedItem: Item? = nil
    @State private var lastDeletedItemIndex: Int? = nil
    @State private var showUndoItemDelete: Bool = false
    @State private var showUndoItemDeletePrompt: Bool = false

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
                            Task {
                                do {
                                    selectedItems = try await supabase
                                        .from("items")
                                        .select()
                                        .eq("list_id", value: selectedList!.id)
                                        .order("index", ascending: true)
                                        .execute()
                                        .value
                                } catch {
                                    toastMessage = "Failed to load items: \(error.localizedDescription)"
                                }
                            }
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
                    onDelete: { idx in
                        if idx < lists.count {
                            // Instead of deleting immediately, show confirmation
                            listIndexToDelete = idx
                            showDeleteConfirmation = true
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
                        items: selectedItems.map { $0.text },
                        onRename: { idx, newText in
                            Task {
                                await renameItem(at: idx, to: newText)
                            }
                        },
                        onAdd: { text in
                            Task {
                                await addItem(name: text)
                            }
                        },
                        onPinchExit: {
                            withAnimation(.easeOut(duration: 0.18)) { selectedList = nil }
                        },
                        onDelete: { idx in
                            if idx < lists.count {
                                Task {
                                    await deleteItem(at: idx)
                                }
                            }
                        },
                        isTopLevel: false
                    )
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
                }
            }
            .animation(.easeInOut(duration: 0.27), value: selectedList)
            // Confirmation dialog for deleting a list
            .confirmationDialog(
                "Are you sure you want to delete this list?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let idx = listIndexToDelete {
                        Task {
                            await deleteList(at: idx)
                        }
                        listIndexToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    listIndexToDelete = nil
                }
            }
            // Confirmation dialog for undoing item delete (shown on shake)
            .confirmationDialog(
                "Undo delete item?",
                isPresented: $showUndoItemDeletePrompt,
                titleVisibility: .visible
            ) {
                Button("Undo", role: .none) {
                    undoDeleteItem()
                }
                Button("Cancel", role: .cancel) {
                    // Just dismiss
                }
            }
        }
        .toast(
            message: toastMessage,
            isPresented: .init(
                get: { toastMessage != nil },
                set: { if !$0 { toastMessage = nil } }
            )
        )
        // No overlay for undo toast
        .background(VeoListView.color1)
        .background(
            // Shake detector: triggers undo prompt if undo is available
            ShakeDetector {
                if showUndoItemDelete, lastDeletedItem != nil {
                    showUndoItemDeletePrompt = true
                }
            }
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
        lists[idx].name = newName
        do {
            _ = try await supabase
                .from("lists")
                .update(["name": newName])
                .eq("id", value: lists[idx].id)
                .execute()
        } catch {
            lists[idx].name = oldName 
            toastMessage = "Rename failed: \(error.localizedDescription)"
        }
    }

    func deleteList(at idx: Int) async {
        guard idx < lists.count else { return }
        let listToDelete = lists[idx]
        lists.remove(at: idx)
        do {
            _ = try await supabase
                .from("lists")
                .delete()
                .eq("id", value: listToDelete.id)
                .execute()
        } catch {
            toastMessage = "Delete failed: \(error.localizedDescription)"
            lists.insert(listToDelete, at: idx) // Reinsert if deletion fails
        }
    }

    func addList(name: String) async {
        guard !name.isEmpty else { return }
        do {
            let currentUser = try await supabase.auth.session.user
            let newList = List(
                id: UUID(),
                user_id: currentUser.id,
                name: name,
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

    func addItem(name: String) async {
        guard !name.isEmpty else { return }
        let newId = UUID()
        do {
        
            let currentUser = try await supabase.auth.session.user
            let newItem = Item(
                id: newId,
                user_id: currentUser.id,
                list_id: selectedList!.id,
                done: false,
                text: name,
                index: 0
            )
            selectedItems.insert(newItem, at: 0)
            _ = try await supabase
                .rpc("increment_item_indices", params: [
                    "list_id_param": selectedList!.id
                ])
                .execute()
            for i in 0..<selectedItems.count {
                selectedItems[i].index += 1
            }
            _ = try await supabase
                .from("items")
                .insert(newItem)
                .execute()
        } catch {
            toastMessage = "Add item failed: \(error.localizedDescription)"
            if let index = selectedItems.firstIndex(where: { $0.id == newId }) {
                selectedItems.remove(at: index)
            }
        }
    }

    func renameItem(at idx: Int, to newName: String) async {
        guard let _ = selectedList, idx < selectedItems.count else { return }
        let oldName = selectedItems[idx].text
        selectedItems[idx].text = newName
        do {
            _ = try await supabase
                .from("items")
                .update(["text": newName])
                .eq("id", value: selectedItems[idx].id)
                .execute()
        } catch {
            selectedItems[idx].text = oldName
            toastMessage = "Rename item failed: \(error.localizedDescription)"
        }
    }

    func deleteItem(at idx: Int) async {
        guard let _ = selectedList, idx < selectedItems.count else { return }
        let itemToDelete = selectedItems[idx]
        selectedItems.remove(at: idx)
        // Store for undo
        lastDeletedItem = itemToDelete
        lastDeletedItemIndex = idx
        showUndoItemDelete = true

        // Hide undo after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if showUndoItemDelete {
                showUndoItemDelete = false
                lastDeletedItem = nil
                lastDeletedItemIndex = nil
                showUndoItemDeletePrompt = false
            }
        }

        do {
            _ = try await supabase
                .from("items")
                .delete()
                .eq("id", value: itemToDelete.id)
                .execute()
            // Update indices of remaining items
            for i in idx..<selectedItems.count {
                selectedItems[i].index -= 1
            }
            // call the decrement RPC
            _ = try await supabase
                .rpc("decrement_item_indices", params: [
                    "list_id_param": selectedList!.id.uuidString,
                    "index_param": "\(itemToDelete.index)"
                ])
                .execute()
        } catch {
            toastMessage = "Delete item failed: \(error.localizedDescription)"
            selectedItems.insert(itemToDelete, at: idx) // Reinsert if deletion fails
            showUndoItemDelete = false
            lastDeletedItem = nil
            lastDeletedItemIndex = nil
            showUndoItemDeletePrompt = false
        }
    }

    func undoDeleteItem() {
        guard let item = lastDeletedItem, let idx = lastDeletedItemIndex else { return }
        selectedItems.insert(item, at: idx)
        showUndoItemDelete = false
        lastDeletedItem = nil
        lastDeletedItemIndex = nil
        showUndoItemDeletePrompt = false

        Task {
            do {
                // Increment indices for items after the restored one
                for i in idx+1..<selectedItems.count {
                    selectedItems[i].index += 1
                }
                _ = try await supabase
                    .rpc("increment_item_indices", params: [
                        "list_id_param": selectedList!.id
                    ])
                    .execute()
                // Insert the item back into the database
                _ = try await supabase
                    .from("items")
                    .insert(item)
                    .execute()
            } catch {
                toastMessage = "Undo failed: \(error.localizedDescription)"
            }
        }
    }
}

// ShakeDetector implementation
struct ShakeDetector: UIViewControllerRepresentable {
    var onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeViewController {
        let controller = ShakeViewController()
        controller.onShake = onShake
        return controller
    }

    func updateUIViewController(_ uiViewController: ShakeViewController, context: Context) {}

    class ShakeViewController: UIViewController {
        var onShake: (() -> Void)?

        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            if motion == .motionShake {
                onShake?()
            }
        }

        override var canBecomeFirstResponder: Bool { true }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            becomeFirstResponder()
        }
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            resignFirstResponder()
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