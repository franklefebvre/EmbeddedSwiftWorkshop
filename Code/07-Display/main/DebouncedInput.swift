class DebouncedInput {
	private let callback: Input.Callback
	private var input: Input? = nil
    private var timer: Timer? = nil
    private(set) var state = false
	
	init(gpioPin: Int, callback: @escaping Input.Callback) {
        self.callback = callback
        let input = Input(gpioPin: gpioPin) { newState in
            guard let timer = self.timer, !timer.isRunning else { return }
            try? timer.start(microseconds: 10_000)
            if newState != self.state {
                self.state = newState
			    callback(newState)
            }
		}
        self.state = input.state
        self.input = input
	    self.timer = Timer() {
            guard let input = self.input else { return }
            let newState = input.state
            if newState != self.state {
                self.state = newState
                callback(newState)
            }
        }
	}
}
