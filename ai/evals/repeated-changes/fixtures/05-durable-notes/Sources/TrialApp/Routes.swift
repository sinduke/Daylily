import DaylilyCore
import DaylilyJSON
public enum NotesApp {
    public static func application(repository: NoteRepository) -> Application {
        Application {
            Get("/health") { "ok" }
            Get("/notes") { JSON([Note]()) }
            Post("/notes") { Status(501, reasonPhrase: "Not Implemented") }
        }
    }
}
