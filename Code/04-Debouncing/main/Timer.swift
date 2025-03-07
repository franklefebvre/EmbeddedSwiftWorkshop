class Timer {
    private var param: Param
    private var timerHandle: esp_timer_handle_t? = nil

    init(callback: @escaping () -> Void) {
        var handle = esp_timer_handle_t(bitPattern: 0)
        self.param = Param(callback: callback)
    	self.timerHandle = withUnsafeMutablePointer(to: &param) { pointer in
            var args = esp_timer_create_args_t(
                callback: timerCallback,
                arg: pointer,
                dispatch_method: ESP_TIMER_ISR,
                name: nil,
                skip_unhandled_events: true
            )
            guard esp_timer_create(&args, &handle) == ESP_OK else { fatalError("timer init failed") }
            return handle
    	}
    }

    deinit {
        if let timerHandle {
            esp_timer_delete(timerHandle)
        }
    }

    func start(microseconds: UInt64, repeating: Bool = false) throws(ESPError) {
        guard let timerHandle else { fatalError() }
        if repeating {
            try ESPError.validate(esp_timer_start_periodic(timerHandle, microseconds))
        } else {
            try ESPError.validate(esp_timer_start_once(timerHandle, microseconds))
        }
    }

    func restart(microseconds: UInt64) throws(ESPError) {
        guard let timerHandle else { fatalError() }
        try ESPError.validate(esp_timer_restart(timerHandle, microseconds))
    }

    func stop() throws(ESPError) {
        try ESPError.validate(esp_timer_stop(timerHandle))
    }

    var isRunning: Bool {
        esp_timer_is_active(timerHandle!)
    }
}

fileprivate func timerCallback(_ arg: UnsafeMutableRawPointer?) {
    guard let arg else { return }
    let paramPtr = arg.assumingMemoryBound(to: Param.self)
    paramPtr.pointee.callback()
}

fileprivate struct Param {
  let callback: () -> Void
}

