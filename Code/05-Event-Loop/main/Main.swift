enum Event {
  case button(Bool)
  case timer
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

  let timer = Timer() {
    eventLoop.postFromISR(.timer)
  }

  eventLoop.register() { timestamp, event in
    switch event {
      case .button(let state):
        counter += 1
        print("\(timestamp): Button \(state), counter = \(counter)")
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
    }
  }

  eventLoop.run()
}
