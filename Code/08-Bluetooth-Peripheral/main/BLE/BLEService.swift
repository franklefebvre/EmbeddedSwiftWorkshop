final class BLEService {
    let uuid: BLEUUID
    let characteristics: [BLECharacteristic]

    init(uuid: BLEUUID, characteristics: [BLECharacteristic]) {
        self.uuid = uuid
        self.characteristics = characteristics
    }

    var definition: ble_gatt_svc_def {
        var def = ble_gatt_svc_def()
        def.type = UInt8(BLE_GATT_SVC_TYPE_PRIMARY)
        def.uuid = uuid.pointer
        def.includes = nil // for now
        let list = UnsafeMutableBufferPointer<ble_gatt_chr_def>.allocate(capacity: characteristics.count + 1)
        let finalIndex = list.initialize(fromContentsOf: characteristics.map { $0.definition })
        var finalDefinition = ble_gatt_chr_def()
        finalDefinition.uuid = nil
        list.initializeElement(at: finalIndex, to: finalDefinition)
        def.characteristics = UnsafeRawPointer(list.baseAddress!).bindMemory(to: ble_gatt_chr_def.self, capacity: 1)
        return def
    }
}

