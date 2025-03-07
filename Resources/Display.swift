class Display {
	enum Orientation {
		case landscape
		case portraitRight
		case portraitLeft
		case landscape180
		case landscapeMirrored
		case portraitMirrored
	}
	
	private var u8g2: u8g2_t
	private var orientationCallbacks: u8g2_cb_t
	private var dirtyRect = Rect.zero
	
	init(sdaPin: Int, sclPin: Int, i2cAddress: UInt8 = 0x78, orientation: Orientation = .landscape) {
		// Initialize HAL
		var halParam = u8g2_esp32_hal_t() // U8G2_ESP32_HAL_DEFAULT
		halParam.bus.i2c.sda = gpio_num_t(Int32(sdaPin))
		halParam.bus.i2c.scl = gpio_num_t(Int32(sclPin))
		halParam.reset = GPIO_NUM_NC // U8G2_ESP32_HAL_UNDEFINED
		halParam.dc = GPIO_NUM_NC // U8G2_ESP32_HAL_UNDEFINED
		u8g2_esp32_hal_init(halParam)

		// Initialize display
		u8g2 = u8g2_t()
		orientationCallbacks = u8g2_cb_r0
		withUnsafeMutablePointer(to: &u8g2) { pointer in
			withUnsafeMutablePointer(to: &orientationCallbacks) { orientationPtr in
				u8g2_Setup_ssd1306_i2c_128x64_noname_f(pointer, orientationPtr, u8g2_esp32_i2c_byte_cb, u8g2_esp32_gpio_and_delay_cb)
			}
		}
		withUnsafeMutableBytes(of: &u8g2) { pointer in
			guard let u8x8 = pointer.assumingMemoryBound(to: u8x8_t.self).baseAddress else { fatalError("Typecast failed") }
			u8x8.pointee.i2c_address = i2cAddress
			u8x8_InitDisplay(u8x8)
		}
		withUnsafeMutablePointer(to: &u8g2) { pointer in
			u8g2_ClearBuffer(pointer)
			u8g2_SendBuffer(pointer)
		}
		withUnsafeMutableBytes(of: &u8g2) { pointer in
			guard let u8x8 = pointer.assumingMemoryBound(to: u8x8_t.self).baseAddress else { fatalError("Typecast failed") }
			u8x8_SetPowerSave(u8x8, 0)
		}
	}

	func clear() {
		withUnsafeMutablePointer(to: &u8g2) { pointer in
			u8g2_ClearBuffer(pointer)
		}
	}

	func refreshAll() {
		withUnsafeMutablePointer(to: &u8g2) { pointer in
			u8g2_SendBuffer(pointer)
		}
		dirtyRect = .zero
	}

	func refresh() {
		let tx = UInt8(dirtyRect.minX / 8)
		let ty = UInt8(dirtyRect.minY / 8)
		let txMax = UInt8((dirtyRect.maxX + 7) / 8)
		let tyMax = UInt8((dirtyRect.maxY + 7) / 8)
		let tw = txMax - tx
		let th = tyMax - ty
		withUnsafeMutablePointer(to: &u8g2) { pointer in
			u8g2_UpdateDisplayArea(pointer, tx, ty, tw, th)
		}
		dirtyRect = .zero
	}

	func frameRect(_ rect: Rect, color: Color = .white, refresh: Bool = false) {
		#error("This is not implemented!")
	}

	func fillRect(_ rect: Rect, color: Color = .white, refresh: Bool = false) {
		#error("This is not implemented!")
	}

	func frameCircle(center: Point, radius: Unit, color: Color = .white, refresh: Bool = false) {
		dirtyRect.union(Rect(x: center.x.value - radius.value, y: center.y.value - radius.value, width: radius.value * 2 + 1, height: radius.value * 2 + 1))
		withUnsafeMutablePointer(to: &u8g2) { pointer in
			u8g2_SetDrawColor(pointer, color.rawValue)
			u8g2_DrawCircle(pointer, center.x.u8g2, center.y.u8g2, radius.u8g2, 0xf)
		}
		if refresh {
			self.refresh()
		}
	}

	func fillCircle(center: Point, radius: Unit, color: Color = .white, refresh: Bool = false) {
		dirtyRect.union(Rect(x: center.x.value - radius.value, y: center.y.value - radius.value, width: radius.value * 2 + 1, height: radius.value * 2 + 1))
		withUnsafeMutablePointer(to: &u8g2) { pointer in
			u8g2_SetDrawColor(pointer, color.rawValue)
			u8g2_DrawDisc(pointer, center.x.u8g2, center.y.u8g2, radius.u8g2, 0xf)
		}
		if refresh {
			self.refresh()
		}
	}

	func fillCircle(_ rect: Rect, color: Color = .white, refresh: Bool = false) {
        guard !rect.isEmpty else { return }
		dirtyRect.union(rect)
		let radius = Unit((min(rect.size.width.value, rect.size.height.value) - 1) / 2)
		let centerX = rect.minX + (rect.size.width.value - 1) / 2
		let centerY = rect.minY + (rect.size.height.value - 1) / 2
		let center = Point(x: centerX, y: centerY)
		withUnsafeMutablePointer(to: &u8g2) { pointer in
			u8g2_SetDrawColor(pointer, color.rawValue)
			u8g2_DrawDisc(pointer, center.x.u8g2, center.y.u8g2, radius.u8g2, 0xf)
		}
		if refresh {
			self.refresh()
		}
	}

	func drawStr(_ str: String, at point: Point, font: UnsafePointer<UInt8> = u8g2_font_ptr_helvR12_tf, color: Color = .white, erase: Bool = true, refresh: Bool = false) {
		withUnsafeMutablePointer(to: &u8g2) { pointer in
			// u8g2_SetDrawColor(pointer, color.rawValue)
            u8g2_SetFont(pointer, font)
            u8g2_SetFontMode(pointer, erase ? 0 : 1)
            let ascent = u8g2.font_ref_ascent
            let descent = u8g2.font_ref_descent
			str.withCString { cstr in
                let width = u8g2_GetUTF8Width(pointer, cstr)
    			let rect = Rect(x: point.x.value, y: point.y.value - Int(ascent), width: width, height: ascent - descent)
                dirtyRect.union(rect)
                if erase {
			        u8g2_SetDrawColor(pointer, color.inversed.rawValue)
			        u8g2_DrawBox(pointer, rect.origin.x.u8g2, rect.origin.y.u8g2, rect.size.width.u8g2, rect.size.height.u8g2)
                }
    			u8g2_SetDrawColor(pointer, color.rawValue)
				u8g2_DrawUTF8(pointer, point.x.u8g2, point.y.u8g2, cstr)
			}
		}
		if refresh {
			self.refresh()
		}
	}
}
