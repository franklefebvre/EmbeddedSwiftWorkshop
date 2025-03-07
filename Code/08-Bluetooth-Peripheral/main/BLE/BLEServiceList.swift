final class BLEServiceList {
    let pointer: UnsafeMutableBufferPointer<ble_gatt_svc_def>
    private let services: [BLEService] // preventing characteristics from being released

    init(services: [BLEService]) {
        let list = UnsafeMutableBufferPointer<ble_gatt_svc_def>.allocate(capacity: services.count + 1)
        let finalIndex = list.initialize(fromContentsOf: services.map { $0.definition })
        var finalDefinition = ble_gatt_svc_def()
        finalDefinition.type = UInt8(BLE_GATT_SVC_TYPE_END)
        list.initializeElement(at: finalIndex, to: finalDefinition)
        self.pointer = list
        self.services = services
        services
            .flatMap { $0.characteristics }
            .filter { $0.allowsSubscription }
            .forEach { BLESubscriptionRegistry.shared.add(characteristic: $0) }
    }

    func startAdvertising(deviceName: String) {
        guard !deviceName.isEmpty, !services.isEmpty else { return } // TODO: throw
        let deviceServiceUUID = services.first!.uuid.pointer
        deviceName.utf8CString.withUnsafeBufferPointer { deviceNamePtr in
            ble_peripheral(deviceNamePtr.baseAddress!, deviceServiceUUID, pointer.baseAddress!)
        }
    }
}
