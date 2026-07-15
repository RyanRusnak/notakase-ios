import Automerge
import Foundation
import SwiftUI

/// A todokase task, read from the shared `tasks.automerge` store so notes can
/// embed a live list. Only the fields a note needs are surfaced.
public struct TodokaseTask: Identifiable, Equatable {
    public let id: String
    public let listId: String
    public let title: String
    public let done: Bool
    public let created: Int64
}

public struct TodokaseProject: Identifiable, Equatable {
    public let id: String
    public let name: String
}

/// Which tasks an embed shows.
public enum TodokaseStatus: String { case open, done, all }

/// Owns the pointer to todokase's `tasks.automerge` file (a security-scoped
/// bookmark, like ``SyncFolder``) and parses it into plain task/project values
/// that notes can embed. Read-only: notakase never writes the task store.
@MainActor
public final class TodokaseTasks: ObservableObject {
    @Published public private(set) var fileURL: URL?
    @Published public private(set) var projects: [TodokaseProject] = []
    @Published public private(set) var tasks: [TodokaseTask] = []
    @Published public private(set) var lastError: String?

    private let bookmarkKey = "notakase.todokaseTasksBookmark"

    public init() {
        fileURL = Self.resolveBookmark(key: bookmarkKey)
        reload()
    }

    public var isSet: Bool { fileURL != nil }

    public var displayPath: String {
        guard let url = fileURL else { return "No tasks file selected" }
        let path = url.path(percentEncoded: false)
        let home = NSHomeDirectory()
        if path.hasPrefix(home + "/") { return "~/" + path.dropFirst(home.count + 1) }
        return path
    }

    // MARK: - File selection

    public func setFile(_ url: URL) {
        do {
            _ = url.startAccessingSecurityScopedResource()
            let data = try url.bookmarkData(
                options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            fileURL = url
            reload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func clearFile() {
        fileURL?.stopAccessingSecurityScopedResource()
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        fileURL = nil
        projects = []
        tasks = []
        lastError = nil
    }

    // MARK: - Reading

    /// Re-read the task store. Cheap and idempotent; called when an embed
    /// appears so the list stays live.
    public func reload() {
        guard let url = fileURL else { return }
        do {
            let data = try Data(contentsOf: url)
            let doc = try Document(data)
            projects = try Self.readProjects(doc)
            tasks = try Self.readTasks(doc)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Tasks for a project name (case-insensitive), filtered by status and
    /// ordered by creation. Pure so it's unit-testable.
    public nonisolated static func filter(
        tasks: [TodokaseTask], projects: [TodokaseProject],
        project: String, status: TodokaseStatus
    ) -> [TodokaseTask] {
        let target = project.lowercased()
        guard let pid = projects.first(where: { $0.name.lowercased() == target })?.id
        else { return [] }
        return
            tasks
            .filter { $0.listId == pid }
            .filter {
                switch status {
                case .open: return !$0.done
                case .done: return $0.done
                case .all: return true
                }
            }
            .sorted { $0.created < $1.created }
    }

    public func tasks(project: String, status: TodokaseStatus) -> [TodokaseTask] {
        Self.filter(tasks: tasks, projects: projects, project: project, status: status)
    }

    // MARK: - Automerge helpers

    private static func readProjects(_ doc: Document) throws -> [TodokaseProject] {
        guard case let .some(.Object(map, .Map)) = try doc.get(obj: .ROOT, key: "projects")
        else { return [] }
        var out: [TodokaseProject] = []
        for key in doc.keys(obj: map) {
            guard case let .some(.Object(obj, .Map)) = try doc.get(obj: map, key: key)
            else { continue }
            let id = nonEmpty(str(doc, obj, "id")) ?? key
            out.append(TodokaseProject(id: id, name: str(doc, obj, "name")))
        }
        return out
    }

    private static func readTasks(_ doc: Document) throws -> [TodokaseTask] {
        guard case let .some(.Object(map, .Map)) = try doc.get(obj: .ROOT, key: "tasks")
        else { return [] }
        var out: [TodokaseTask] = []
        for key in doc.keys(obj: map) {
            guard case let .some(.Object(obj, .Map)) = try doc.get(obj: map, key: key)
            else { continue }
            let id = nonEmpty(str(doc, obj, "id")) ?? key
            out.append(
                TodokaseTask(
                    id: id, listId: str(doc, obj, "list"),
                    title: str(doc, obj, "title"),
                    // A task is done iff it carries a `doneAt` timestamp.
                    done: intOrNil(doc, obj, "doneAt") != nil,
                    created: intOrNil(doc, obj, "created") ?? 0))
        }
        return out
    }

    private static func str(_ doc: Document, _ obj: ObjId, _ key: String) -> String {
        if case let .some(.Scalar(.String(s))) = try? doc.get(obj: obj, key: key) { return s }
        return ""
    }
    private static func intOrNil(_ doc: Document, _ obj: ObjId, _ key: String) -> Int64? {
        if case let .some(.Scalar(.Int(i))) = try? doc.get(obj: obj, key: key) { return i }
        return nil
    }
    private static func nonEmpty(_ s: String) -> String? { s.isEmpty ? nil : s }

    // MARK: - Bookmarks

    private static func resolveBookmark(key: String) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        guard
            let url = try? URL(
                resolvingBookmarkData: data, options: [], relativeTo: nil,
                bookmarkDataIsStale: &stale)
        else { return nil }
        _ = url.startAccessingSecurityScopedResource()
        return url
    }
}
