@_cdecl("app_main")
func main() {
  var counter = 0

  let led = Led(gpioPin: 22)
  let button = DebouncedInput(gpioPin: 21) { state in
    counter += 1
  }

  var ledState = false
  var buttonState = button.state

  led.setLed(value: ledState)

  while true {
    if button.state != buttonState {
      buttonState = button.state
      print("Counter: \(counter)")
      if buttonState == false {
        ledState.toggle()
        led.setLed(value: ledState)
      }
    }
    vTaskDelay(10) // 100 ms
  }
}
