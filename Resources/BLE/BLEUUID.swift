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
        #error("This is not implemented!")
        return nil
    }
}
