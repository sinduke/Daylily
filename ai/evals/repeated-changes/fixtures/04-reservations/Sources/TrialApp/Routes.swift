import DaylilyCore
import DaylilyJSON
public enum ReservationApp {
    public static func application(inventory: Inventory = Inventory()) -> Application {
        Application {
            Get("/health") { "ok" }
            Get("/stock") { JSON(Stock(available: 0)) }
            Post("/reservations") { Status(501, reasonPhrase: "Not Implemented") }
        }
    }
}
