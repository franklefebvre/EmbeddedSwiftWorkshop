import AccessorySetupKit
import CoreBluetooth

extension RemoteDevice {
    init?(_ accessory: ASAccessory) {
        guard let identifier = accessory.bluetoothIdentifier else { return nil }
        self.uuid = identifier
        self.name = accessory.displayName
    }
}

class DiscoveryService {
    enum Event {
        case activated(peripherals: [RemoteDevice])
        case selected(RemoteDevice)
    }

    var callback: ((Event) -> Void)?

    private let session: ASAccessorySession
    private var selectedAccessory: ASAccessory?

    init() {
        session = ASAccessorySession()
        session.activate(on: .main) { [weak self] event in
            guard let self else { return }
            switch event.eventType {
            case .activated:
                let devices = session.accessories.compactMap(RemoteDevice.init)
                if !devices.isEmpty {
                    callback?(.activated(peripherals: devices))
                }
            case .accessoryAdded:
                // store accessory, wait for .pickerDidDismiss
                selectedAccessory = event.accessory
            case .accessoryRemoved:
                selectedAccessory = nil
            case .pickerDidDismiss:
                if let device = selectedAccessory.flatMap(RemoteDevice.init) {
                    callback?(.selected(device))
                }
            default:
                print(event.eventType)
                print(event)
                break
            }
        }
    }

    func showPicker(serviceUUID: CBUUID) {
        let descriptor = ASDiscoveryDescriptor()
        descriptor.bluetoothServiceUUID = serviceUUID
        let displayItem = ASPickerDisplayItem(name: "ESP32", productImage: UIImage(named: "ESP32-C6")!, descriptor: descriptor)
        session.showPicker(for: [displayItem]) { error in
            if let error = error {
                print("Error: \(error)")
            }
        }
    }
}
