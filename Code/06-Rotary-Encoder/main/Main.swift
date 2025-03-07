enum Event {
  case button(Bool)
  case timer
  case rotary(RotaryController.Direction)
}

@_cdecl("app_main")
func main() {
  let eventLoop = EventLoop(queueLength: 10, events: Event.self)

  var counter = 0
  var ledState = false

  let led = Led(gpioPin: 22)
  led.setLed(value: ledState)

  _ = DebouncedInput(gpioPin: 21) { state in
    eventLoop.postFromISR(.button(state))
  }

  _ = RotaryController(clkPin: 19, dtPin: 20) { direction in
    eventLoop.postFromISR(.rotary(direction))
  }

  let timer = Timer() {
    eventLoop.postFromISR(.timer)
  }

  eventLoop.register() { timestamp, event in
    switch event {
      case .button(let state):
        print("\(timestamp): Button \(state)")
        if state == false {
          if timer.isRunning {
            try? timer.stop()
          } else {
            try? timer.start(microseconds: 100_000, repeating: true)
          }
        }
      case .timer:
        ledState.toggle()
        led.setLed(value: ledState)
      case .rotary(let direction):
        counter += direction == .clockwise ? 1 : -1
        print("\(timestamp): Rotating, counter = \(counter)")
    }
  }

  eventLoop.run()
}
