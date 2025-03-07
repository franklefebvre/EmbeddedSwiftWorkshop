class Input {
    private let pin: gpio_num_t

    init(gpioPin: Int) {
        self.pin = gpio_num_t(Int32(gpioPin))

        guard gpio_reset_pin(pin) == ESP_OK else {
            fatalError("ERROR: gpio_reset_pin")
        }
        guard gpio_set_direction(pin, GPIO_MODE_INPUT) == ESP_OK else {
            fatalError("ERROR: gpio_set_direction")
        }
    }

    var state: Bool {
        gpio_get_level(pin) != 0
    }
}
