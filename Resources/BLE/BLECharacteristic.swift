final class BLECharacteristic {
    typealias ReadHandler = (UnsafeMutableRawPointer) -> Int
    typealias WriteHandler = (UnsafeMutableRawPointer, Int) -> Void

    struct Arg {
        let valHandlePtr: UnsafeMutablePointer<UInt16>
        let valueSize: Int
        let valueBuffer: UnsafeMutableRawPointer
        let readHandler: ReadHandler?
        let writeHandler: WriteHandler?

        init(valueSize: Int, readHandler: ReadHandler?, writeHandler: WriteHandler?) {
            self.valHandlePtr = UnsafeMutablePointer<UInt16>.allocate(capacity: 1)
            self.valueSize = valueSize
            self.valueBuffer = UnsafeMutableRawPointer.allocate(byteCount: valueSize, alignment: MemoryLayout<UInt16>.alignment)
            self.readHandler = readHandler
            self.writeHandler = writeHandler
        }
    }

    let uuid: BLEUUID
    let allowsSubscription: Bool
    let arg: UnsafeMutablePointer<Arg>
    let argPtr: UnsafeMutableRawPointer

    init(uuid: BLEUUID, valueSize: Int, allowsSubscription: Bool, readHandler: ReadHandler?, writeHandler: WriteHandler?) {
        self.uuid = uuid
        self.allowsSubscription = allowsSubscription && readHandler != nil
        let ptr = UnsafeMutablePointer<Arg>.allocate(capacity: 1)
        ptr.pointee = Arg(valueSize: valueSize, readHandler: readHandler, writeHandler: writeHandler)
        self.arg = ptr
        self.argPtr = UnsafeMutableRawPointer(ptr)
    }

    func updateSubscribers() {
        let connHandles = BLESubscriptionRegistry.shared.activeSubscriberConnections(to: self)
        let attrHandle = arg.pointee.valHandlePtr.pointee
        connHandles.forEach { connHandle in
            ble_gatts_indicate(connHandle, attrHandle)
        }
    }

    var definition: ble_gatt_chr_def {
        var def = ble_gatt_chr_def()
        def.uuid = uuid.pointer
        def.access_cb = characteristic_access_handler
        def.arg = argPtr
        def.descriptors = nil // ble_gatt_dsc_def
        def.flags = UInt16((arg.pointee.readHandler != nil ? BLE_GATT_CHR_F_READ : 0) | (allowsSubscription ? BLE_GATT_CHR_F_INDICATE : 0) | (arg.pointee.writeHandler != nil ? BLE_GATT_CHR_F_WRITE : 0)) // BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_INDICATE | BLE_GATT_CHR_F_WRITE
        def.min_key_size = 0
        def.val_handle = arg.pointee.valHandlePtr
        def.cpfd = nil
        return def
    }
}

@_cdecl("characteristic_access_handler")
fileprivate func characteristic_access_handler(_ connHandle: UInt16, _ attrHandle: UInt16, _ ctxt: UnsafeMutablePointer<ble_gatt_access_ctxt>?, _ arg: UnsafeMutableRawPointer?) -> Int32 {
    guard let ctxt = ctxt?.pointee, let arg = arg?.assumingMemoryBound(to: BLECharacteristic.Arg.self).pointee else { return BLE_ATT_ERR_UNLIKELY }

    switch Int32(ctxt.op) {

    /* Read characteristic event */
    case BLE_GATT_ACCESS_OP_READ_CHR:
        guard attrHandle == arg.valHandlePtr.pointee, let handler = arg.readHandler else { return BLE_ATT_ERR_UNLIKELY }
        let size = UInt16(handler(arg.valueBuffer))
        let err = r_os_mbuf_append(ctxt.om, arg.valueBuffer, size)
        return err == 0 ? 0 : BLE_ATT_ERR_INSUFFICIENT_RES

    /* Write characteristic event */
    case BLE_GATT_ACCESS_OP_WRITE_CHR:
        guard attrHandle == arg.valHandlePtr.pointee, let handler = arg.writeHandler else { return BLE_ATT_ERR_UNLIKELY }
        guard let buf = ctxt.om.pointee.om_data else { return BLE_ATT_ERR_UNLIKELY }
        let size = ctxt.om.pointee.om_len
        handler(buf, Int(size))
        return 0

    default:
        return BLE_ATT_ERR_UNLIKELY
    }
}
