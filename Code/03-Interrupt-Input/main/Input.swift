class Input {
    typealias Callback = ((Bool) -> Void)

    struct InterruptHandlerContext {
        var pin: gpio_num_t
        var callback: Callback
    }

    private let pin: gpio_num_t
    private let callback: Callback?
    private let param: UnsafeMutablePointer<InterruptHandlerContext>?

    init(gpioPin: Int, callback: Callback? = nil) {
        self.pin = gpio_num_t(Int32(gpioPin))
        self.callback = callback

        guard gpio_reset_pin(pin) == ESP_OK else {
            fatalError("ERROR: gpio_reset_pin")
        }
        guard gpio_set_direction(pin, GPIO_MODE_INPUT) == ESP_OK else {
            fatalError("ERROR: gpio_set_direction")
        }

        if let callback {
            let param = UnsafeMutablePointer<InterruptHandlerContext>.allocate(capacity: 1)
            param.pointee.pin = pin
            param.pointee.callback = callback
            self.param = param

            Self.installISRServiceOnce

            guard gpio_set_intr_type(pin, GPIO_INTR_ANYEDGE) == ESP_OK else {
                fatalError("ERROR: gpio_set_intr_type")
            }
            guard gpio_isr_handler_add(pin, interruptHandler, param) == ESP_OK else {
                fatalError("ERROR: gpio_isr_handler_add")
            }
            guard gpio_intr_enable(pin) == ESP_OK else {
                fatalError("ERROR: gpio_intr_enable")
            }
        } else {
            self.param = nil
        }
    }

    deinit {
        if callback != nil {
            gpio_isr_handler_remove(pin)
            gpio_intr_disable(pin)
        }
    }

    var state: Bool {
        gpio_get_level(pin) != 0
    }

    private static let installISRServiceOnce: Void = {
        gpio_install_isr_service(ESP_INTR_FLAG_LEVEL1) // LEVEL1 is lowest priority, NMI (LEVEL7) is highest
    }()
}

fileprivate func interruptHandler(_ arg: UnsafeMutableRawPointer?) {
    guard let arg else { return }
    let param = arg.assumingMemoryBound(to: Input.InterruptHandlerContext.self).pointee
    param.callback(gpio_get_level(param.pin) != 0)
}
