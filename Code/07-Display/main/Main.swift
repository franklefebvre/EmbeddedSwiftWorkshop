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

  let display = Display(sdaPin: 0, sclPin: 1)
  display.drawStr("\(counter)", at: Point(x: 20, y: 30), font: u8g2_font_ptr_lubR24_tf, refresh: true)

  let barX = 14
  let barY = 50
  let barHeight = 6
  display.frameRect(Rect(x: barX - 2, y: barY - 2, width: 100 + 4, height: barHeight + 4), refresh: true)

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
        counter = max(0, min(100, counter))
        print("\(timestamp): Rotating, counter = \(counter)")
        display.drawStr("\(counter)  ", at: Point(x: 20, y: 30), font: u8g2_font_ptr_lubR24_tf, refresh: true)
        display.frameRect(Rect(x: barX, y: barY, width: counter, height: barHeight))
        display.frameRect(Rect(x: barX + counter, y: barY, width: 100 - counter, height: barHeight), color: .black)
        display.refresh()
    }
  }

  eventLoop.run()
}
