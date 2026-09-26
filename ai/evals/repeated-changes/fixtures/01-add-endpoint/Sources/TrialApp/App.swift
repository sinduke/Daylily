import DaylilyCore
import DaylilyOpenAPI

public enum AddEndpoint {
    public static func application() -> Application {
        Application { Get("/health") { "ok" } }
    }
}
