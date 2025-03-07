//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors.
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

// The code will blink an LED on GPIO22. To change the pin, modify Led(gpioPin: 22)
@_cdecl("app_main")
func main() {
  print("Hello from Swift on ESP32-C6!")

  var ledValue: Bool = false
  let blinkDelayMs: UInt32 = 500
  let led = Led(gpioPin: 22)

  while true {
    led.setLed(value: ledValue)
    ledValue.toggle()  // Toggle the boolean value
    print("LED state: \(ledValue)")
    vTaskDelay(blinkDelayMs / (1000 / UInt32(configTICK_RATE_HZ)))
  }
}
