final class BLESubscriptionRegistry {
    final class Subscription {
        var characteristic: BLECharacteristic
        var subscriberConnHandles: [UInt16]

        init(characteristic: BLECharacteristic) {
            self.characteristic = characteristic
            self.subscriberConnHandles = []
        }
    }

    static let shared = BLESubscriptionRegistry()

    private var subscriptions: [Subscription] = []

    func add(characteristic: BLECharacteristic) {
        subscriptions.append(.init(characteristic: characteristic))
    }

    func handleSubscriptionRequest(event: ble_gap_event) {
        let connHandle = event.subscribe.conn_handle
        let attrHandle = event.subscribe.attr_handle
        guard connHandle != BLE_HS_CONN_HANDLE_NONE else { return }
        let subscription = subscriptions.first {
            $0.characteristic.arg.pointee.valHandlePtr.pointee == attrHandle
        }
        guard let subscription else { return }
        if event.subscribe.cur_indicate != 0 {
            if !subscription.subscriberConnHandles.contains(connHandle) {
                subscription.subscriberConnHandles.append(connHandle)
                print("Adding \(connHandle) to subscriber list for \(attrHandle)")
            }
        } else {
            subscription.subscriberConnHandles.removeAll { $0 == connHandle }
            print("Removing \(connHandle) from subscriber list for \(attrHandle)")
        }
    }

    func activeSubscriberConnections(to characteristic: BLECharacteristic) -> [UInt16] {
        subscriptions.first { $0.characteristic === characteristic }?.subscriberConnHandles ?? []
    }
}

@_cdecl("gatt_svr_subscribe_cb")
func gatt_svr_subscribe_cb(_ event: UnsafeMutablePointer<ble_gap_event>?) {
    guard let event = event?.pointee else { return }
    BLESubscriptionRegistry.shared.handleSubscriptionRequest(event: event)
}
