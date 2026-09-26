import TrialApp
import DaylilyCore
import DaylilyTesting
import Foundation
import Testing
@Suite struct DurableNoteAcceptance {
    func directory() throws -> URL {
        let p=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: p, withIntermediateDirectories: true); return p
    }
    @Test func routesPersistAndConcurrentWritesReload() async throws {
        let dir=try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let file=dir.appendingPathComponent("notes.json")
        let repo=try NoteRepository(fileURL: file)
        let app=TestClient(NotesApp.application(repository: repo))
        #expect(try await app.post("/notes", body: "{\"text\":\"  first  \"}").status.code == 200)
        #expect(try await app.post("/notes", body: "{\"text\":\"   \"}").status.code == 400)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<15 { group.addTask { _ = try await repo.create(text: "note-\(i)") } }
            try await group.waitForAll()
        }
        let reopened=try NoteRepository(fileURL: file)
        let notes=await reopened.list()
        #expect(notes.count == 16)
        #expect(notes.map(\.id) == Array(1...16))
        #expect(notes.first?.text == "first")
        let response=try await TestClient(NotesApp.application(repository: reopened)).get("/notes")
        #expect(try JSONDecoder().decode([Note].self, from: Data(response.body)) == notes)
        try await app.get("/health").requireBody("ok")
    }
    @Test func corruptStorageAndWriteFailureAreNotHidden() async throws {
        let dir=try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let file=dir.appendingPathComponent("notes.json")
        try Data("broken".utf8).write(to: file)
        do { _ = try NoteRepository(fileURL: file); Issue.record("corrupt file accepted") } catch {}
        try FileManager.default.removeItem(at: file)
        let repo=try NoteRepository(fileURL: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        do { _ = try await repo.create(text: "cannot save"); Issue.record("write failure accepted") } catch {}
        #expect(await repo.list().isEmpty)
    }
}
