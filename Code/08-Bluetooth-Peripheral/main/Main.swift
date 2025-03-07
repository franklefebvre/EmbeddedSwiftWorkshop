enum Event {
  case button(Bool)
  case timer
  case rotary(RotaryController.Direction)
  case counter(Int)
}

var button: DebouncedInput?
var rotary: RotaryController?
var gdisplay: Display?
var ble: BLEServiceList?

@_cdecl("app_main")
func main() {
  let eventLoop = EventLoop(queueLength: 10, events: Event.self)

  var counter = 0
  var ledState = false

  let led = Led(gpioPin: 22)
  led.setLed(value: ledState)

  button = DebouncedInput(gpioPin: 21) { state in
    eventLoop.postFromISR(.button(state))
  }

  rotary = RotaryController(clkPin: 19, dtPin: 20) { direction in
    eventLoop.postFromISR(.rotary(direction))
  }

  let timer = Timer() {
    eventLoop.postFromISR(.timer)
  }

  let display = Display(sdaPin: 0, sclPin: 1)
  gdisplay = display
  display.drawStr("\(counter)", at: Point(x: 20, y: 30), font: u8g2_font_ptr_lubR24_tf, refresh: true)

  let barX = 14
  let barY = 50
  let barHeight = 6
  display.frameRect(Rect(x: barX - 2, y: barY - 2, width: 100 + 4, height: barHeight + 4), refresh: true)

  let characteristic = BLECharacteristic(
    uuid: .init(uuid128: "D02E9282-89EF-4051-AAF0-C2C01B43DF4C")!,
    valueSize: MemoryLayout<UInt8>.size,
    allowsSubscription: true,
    readHandler: { buf in
      buf.assumingMemoryBound(to: UInt8.self).pointee = UInt8(counter)
      return MemoryLayout<UInt8>.size
    },
    writeHandler: { buf, size in
      guard size == MemoryLayout<UInt8>.size else { return }
      let value = Int(buf.assumingMemoryBound(to: UInt8.self).pointee)
      eventLoop.post(.counter(value))
    }
  )
  let service = BLEService(
    uuid: .init(uuid128: "11808D84-EC34-4D06-AAB7-01F715D88F90")!,
    characteristics: [characteristic]
  )
  let serviceList = BLEServiceList(services: [service])
  ble = serviceList

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
        updateCounter(counter + (direction == .clockwise ? 1 : -1))
        characteristic.updateSubscribers()
      case .counter(let value):
        updateCounter(value)
    }
  }

  serviceList.startAdvertising(deviceName: "ARCtic")

  eventLoop.run()

  func updateCounter(_ value: Int) {
    counter = max(0, min(100, value))
    display.drawStr("\(counter)  ", at: Point(x: 20, y: 30), font: u8g2_font_ptr_lubR24_tf, refresh: true)
    display.fillRect(Rect(x: barX, y: barY, width: counter, height: barHeight))
    display.fillRect(Rect(x: barX + counter, y: barY, width: 100 - counter, height: barHeight), color: .black)
    display.refresh()
  }
}
