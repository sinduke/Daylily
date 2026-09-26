import DaylilyCore
import NIOConcurrencyHelpers

/// One admission gate shared by every connection of a server instance. Admission
/// is synchronous, so even an indefinitely suspended observer cannot accumulate
/// tasks waiting to enter an actor or append to an unbounded queue.
final class ResponseTransferDispatcher: Sendable {
    private struct State {
        var inFlight = 0
        var completedEvents: UInt64 = 0
        var droppedEvents: UInt64 = 0
    }

    private let observer: any ResponseTransferObserver
    private let capacity: Int
    private let state = NIOLockedValueBox(State())

    init(observer: any ResponseTransferObserver, capacity: Int) {
        precondition(capacity > 0, "Response observer capacity must be positive")
        self.observer = observer
        self.capacity = capacity
    }

    var snapshot: ResponseTransferDeliverySnapshot {
        state.withLockedValue {
            ResponseTransferDeliverySnapshot(
                capacity: capacity,
                inFlight: $0.inFlight,
                completedEvents: $0.completedEvents,
                droppedEvents: $0.droppedEvents
            )
        }
    }

    func submit(_ event: ResponseTransferEvent) {
        let admitted = state.withLockedValue { state in
            guard state.inFlight < capacity else {
                state.droppedEvents &+= 1
                return false
            }
            state.inFlight += 1
            return true
        }
        guard admitted else { return }
        Task {
            await observer.record(event)
            state.withLockedValue {
                $0.inFlight -= 1
                $0.completedEvents &+= 1
            }
        }
    }
}
