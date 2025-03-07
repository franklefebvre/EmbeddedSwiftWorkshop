struct Queue<T> {
	private let queue: QueueHandle_t
	
	init(count: UInt32, elements: T.Type) {
		queue = xQueueGenericCreate(count, UInt32(MemoryLayout<T>.size), queueQUEUE_TYPE_BASE)
	}
	
	func send(_ element: T, wait ticksToWait: TickType_t = 0) throws(OSError) {
		var element = element // withUnsafePointer takes inout parameter, element must be mutable.
		let rc = withUnsafePointer(to: &element) { pointer in
			xQueueGenericSend(queue, pointer, ticksToWait, queueSEND_TO_BACK)
		}
		try OSError.validate(rc)
	}
		
	func sendFromISR(_ element: T) throws(OSError) {
		var element = element // withUnsafePointer takes inout parameter, element must be mutable.
		let rc = withUnsafeMutablePointer(to: &element) { pointer in
			var higherPriorityTaskWoken: BaseType_t = pdFALSE
			let rc = xQueueGenericSendFromISR(queue, pointer, &higherPriorityTaskWoken, queueSEND_TO_BACK)
			if higherPriorityTaskWoken != pdFALSE {
				vPortYieldFromISR()
			}
			return rc
		}
		try OSError.validate(rc)
	}
	
	func receive(wait ticksToWait: TickType_t = portMAX_DELAY) -> T? {
		let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
		defer {
			pointer.deallocate()
		}
		guard xQueueReceive(queue, pointer, ticksToWait) == pdPASS else {
			return nil
		}
		let element = pointer.pointee
		return element
	}
	
	func reset() {
		xQueueGenericReset(queue, pdFALSE)
	}
}
