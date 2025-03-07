struct Unit {
    private(set) var value: Int
    var u8g2: u8g2_uint_t { u8g2_uint_t(UInt16(value)) }
    init(_ value: some BinaryInteger) {
        self.value = Int(value)
    }
}

extension Unit: ExpressibleByIntegerLiteral {
    init(integerLiteral: IntegerLiteralType) {
        self.init(integerLiteral)
    }
}

struct Point {
	var x: Unit
	var y: Unit

	init(x: Unit, y: Unit) {
		self.x = x
		self.y = y
	}

    init(x: some BinaryInteger, y: some BinaryInteger) {
        self.init(x: Unit(x), y: Unit(y))
    }

	static let zero = Self(x: 0, y: 0)

	mutating func moveBy(offsetX: Unit, offsetY: Unit) {
        x = Unit(x.value + offsetX.value)
        y = Unit(y.value + offsetY.value)
	}
}

struct Size {
	var width: Unit
	var height: Unit

	init(width: Unit, height: Unit) {
		self.width = width
		self.height = height
	}

    init(width: some BinaryInteger, height: some BinaryInteger) {
        self.init(width: Unit(width), height: Unit(height))
    }

	static let zero = Self(width: 0, height: 0)
}

struct Rect {
	var origin: Point
	var size: Size
}

extension Rect {
	init(x: Unit, y: Unit, width: Unit, height: Unit) {
		self.init(origin: .init(x: x, y: y), size: .init(width: width, height: height))
	}

	init(x: some BinaryInteger, y: some BinaryInteger, width: some BinaryInteger, height: some BinaryInteger) {
		self.init(origin: .init(x: x, y: y), size: .init(width: width, height: height))
	}

	static let zero = Self(origin: .zero, size: .zero)

	var minX: Int { origin.x.value }
	var minY: Int { origin.y.value }
	var maxX: Int { origin.x.value + size.width.value }
	var maxY: Int { origin.y.value + size.height.value }
    
    var isEmpty: Bool { size.width.value == 0 || size.height.value == 0 }

	mutating func moveBy(offsetX: Unit, offsetY: Unit) {
		origin.moveBy(offsetX: offsetX, offsetY: offsetY)
	}

	mutating func union(_ other: Rect) {
		guard other.size.width.value != 0, other.size.height.value != 0 else { return }
		guard size.width.value != 0, size.height.value != 0 else {
			self = other
			return
		}
		let maxX = max(self.maxX, other.maxX)
		let maxY = max(self.maxY, other.maxY)
		origin.x = Unit(min(origin.x.value, other.origin.x.value))
		origin.y = Unit(min(origin.y.value, other.origin.y.value))
		size.width = Unit(maxX - origin.x.value)
		size.height = Unit(maxY - origin.y.value)
	}
}

enum Color: UInt8 {
	case black = 0
	case white = 1

    var inversed: Self {
        switch self {
            case .black: .white
            case .white: .black
        }
    }
}
