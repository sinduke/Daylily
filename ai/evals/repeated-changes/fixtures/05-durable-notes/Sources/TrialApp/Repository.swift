import Foundation
import DaylilyCore
public actor NoteRepository {
    private let fileURL: URL
    private var notes: [Note] = []
    public init(fileURL: URL) throws { self.fileURL=fileURL }
    public func list() -> [Note] { notes }
    public func create(text: String) throws -> Note {
        let note = Note(id: notes.count + 1, text: text)
        notes.append(note)
        return note
    }
}
