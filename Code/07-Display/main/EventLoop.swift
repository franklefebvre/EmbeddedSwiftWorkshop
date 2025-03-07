struct TimedEvent<Event> {
    let timestamp: Int64
    let event: Event

    init(_ event: Event) {
        self.timestamp = esp_timer_get_time()
        self.event = event
    }
}

class EventLoop<Event> {
    typealias EventHandler = (Int64, Event) -> Void

    private let eventQueue: Queue<TimedEvent<Event>>
    private var handlers: [EventHandler]

    init(queueLength: UInt32, events: Event.Type) {
        eventQueue = Queue(count: queueLength, elements: TimedEvent<Event>.self)
        handlers = []
    }

    func register(handler: @escaping EventHandler) {
        handlers.append(handler)
    }

    func post(_ event: Event) {
        try? eventQueue.send(TimedEvent(event))
    }

    func postFromISR(_ event: Event) {
        try? eventQueue.sendFromISR(TimedEvent(event))
    }

    func run() -> Never {
        while true {
            guard let element = eventQueue.receive() else { continue }
            for handler in handlers {
                handler(element.timestamp, element.event)
            }
        }
    }
}
