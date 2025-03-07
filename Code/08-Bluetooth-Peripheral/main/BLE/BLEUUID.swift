final class BLEUUID {
    let pointer: UnsafePointer<ble_uuid_t>

    init(uuid16: UInt16) {
        let uuid = UnsafeMutablePointer<ble_uuid16_t>.allocate(capacity: 1)
        uuid.pointee.u.type = UInt8(BLE_UUID_TYPE_16)
        uuid.pointee.value = uuid16.littleEndian
        pointer = UnsafeRawPointer(uuid).bindMemory(to: ble_uuid_t.self, capacity: 1)
    }

    init(uuid32: UInt32) {
        let uuid = UnsafeMutablePointer<ble_uuid32_t>.allocate(capacity: 1)
        uuid.pointee.u.type = UInt8(BLE_UUID_TYPE_32)
        uuid.pointee.value = uuid32.littleEndian
        pointer = UnsafeRawPointer(uuid).bindMemory(to: ble_uuid_t.self, capacity: 1)
    }

    init?(uuid128: String) {
        guard let bytes = Self.decode(uuidString: uuid128) else { return nil }
        let uuid = UnsafeMutablePointer<ble_uuid128_t>.allocate(capacity: 1)
        uuid.pointee.u.type = UInt8(BLE_UUID_TYPE_128)
        uuid.pointee.value = bytes
        pointer = UnsafeRawPointer(uuid).bindMemory(to: ble_uuid_t.self, capacity: 1)
    }

    static func decode(uuidString: String) -> (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)? {
        // expected format: "%08X-%04X-%04X-%04X-%012X"
        let parts = uuidString.utf8.split(separator: 0x2d) // "-"
        guard parts.map({ $0.count }) == [8, 4, 4, 4, 12] else { return nil }
        let v = parts
            .flatMap { Self.split(chars: Array($0), length: 2) }
            .compactMap { UInt8($0, radix: 16) }
        guard v.count == 16 else { return nil }
        return (v[15], v[14], v[13], v[12], v[11], v[10], v[9], v[8], v[7], v[6], v[5], v[4], v[3], v[2], v[1], v[0])
    }

    private static func split(chars: [UInt8], length: Int) -> [String] {
        stride(from: 0, to: chars.count, by: length)
            .map { chars[$0 ..< $0+2] }
            .compactMap { String(validating: $0, as: UTF8.self) }
    }
}
