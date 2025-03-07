@_cdecl("app_main")
func main() {
  let led = Led(gpioPin: 22)
  let button = Input(gpioPin: 21)

  var ledState = false
  var buttonState = button.state
  var counter = 0

  led.setLed(value: ledState)

  while true {
    if button.state != buttonState {
      buttonState = button.state
      counter += 1
      print("Counter: \(counter)")
      if buttonState == false {
        ledState.toggle()
        led.setLed(value: ledState)
      }
    }
    vTaskDelay(10) // 100 ms
  }
}
