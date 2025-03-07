class RotaryController {
    enum Direction {
        case clockwise
        case counterclockwise
    }

    private let dataInput: Input
    private let clockInput: DebouncedInput
    private let callback: (Direction) -> Void

    init(clkPin: Int, dtPin: Int, callback: @escaping (Direction) -> Void) {
        let dataInput = Input(gpioPin: dtPin)
        let clockInput = DebouncedInput(gpioPin: clkPin) { state in
            guard state == false else { return } // only consider falling edge
            callback(dataInput.state ? .clockwise : .counterclockwise)
        }
        self.dataInput = dataInput
        self.clockInput = clockInput
        self.callback = callback
    }
}