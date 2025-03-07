import Foundation
import CoreBluetooth

// Bluetooth byte-order convention is little endian.
// From GATT spec:
// "Multi-octet fields within the GATT Profile shall be sent least significant octet first (little endian)."

protocol EndianCapable {
    var littleEndian: Self { get }
}

extension UInt8: EndianCapable {}

struct RemoteDevice: Equatable, Identifiable, Codable {
    var uuid: UUID
    var name: String?

    var id: UUID { uuid }
}

extension RemoteDevice {
    init(_ peripheral: CBPeripheral) {
        self.uuid = peripheral.identifier
        self.name = peripheral.name
    }
}

@Observable
final class BluetoothConnectionManager<Value: EndianCapable>: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    enum ConnectionState: Equatable {
        case unknown
        case unavailable(message: String)
        case ready
        case scanning
        case discovered(peripherals: [RemoteDevice])
        case connecting(peripheral: RemoteDevice)
        case connected(peripheral: RemoteDevice)
    }

    private let bleQueue = DispatchQueue(label: "ble")
    
    private var discoveredPeripherals = Set<CBPeripheral>()
    private var remotePeripheral: CBPeripheral?
    private var remoteService: CBService?
    private var remoteCharacteristic: CBCharacteristic?

    private var centralManager: CBCentralManager
    private let serviceUUID: CBUUID
    private let characteristicUUID: CBUUID

    private(set) var state: ConnectionState = .unknown
    private(set) var readValue: Value?

    init(serviceUUID: CBUUID, characteristicUUID: CBUUID, valueType: Value.Type) {
        self.serviceUUID = serviceUUID
        self.characteristicUUID = characteristicUUID
        self.centralManager = CBCentralManager(delegate: nil, queue: bleQueue)
        super.init()
        self.centralManager.delegate = self
    }

    // CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            state = .ready
            readValue = nil
        case .poweredOff:
            // Alert user to turn on Bluetooth
            state = .unavailable(message: "Please turn on Bluetooth")
            readValue = nil
            break
        case .resetting:
            // Wait for next state update and consider logging interruption of Bluetooth service
            readValue = nil
            break
        case .unauthorized:
            // Alert user to enable Bluetooth permission in app Settings
            state = .unavailable(message: "Please enable Bluetooth permission")
            readValue = nil
            break
        case .unsupported:
            // Alert user their device does not support Bluetooth and app will not work as expected
            state = .unavailable(message: "Bluetooth is not supported on this device")
            readValue = nil
            break
        case .unknown:
            // Wait for next state update
            break
        @unknown default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        discoveredPeripherals.insert(peripheral)
        switch state {
        case .scanning, .discovered:
            Task.detached { @MainActor [weak self] in
                guard let self else { return }
                state = .discovered(peripherals: discoveredPeripherals.map(RemoteDevice.init))
            }
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // TODO: report error
    }

    // CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let service = peripheral.services?.first else { return }
        remotePeripheral = peripheral
        remoteService = service
        readValue = nil
        peripheral.discoverCharacteristics([characteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let characteristic = service.characteristics?.first else { return }
        // characteristic.uuid contains the value we want, but we know it already
        remoteCharacteristic = characteristic
        peripheral.readValue(for: characteristic)
        peripheral.setNotifyValue(true, for: characteristic)
        state = .connected(peripheral: .init(peripheral))
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        // Update readValue with characteristic's value
        guard let data = characteristic.value, data.count == MemoryLayout<Value>.size else { return }
        let ptr = UnsafeMutablePointer<Value>.allocate(capacity: 1)
        data.copyBytes(to: UnsafeMutableRawBufferPointer(start: ptr, count: MemoryLayout<Value>.size))
        readValue = ptr.pointee.littleEndian
    }
}

extension BluetoothConnectionManager {
    func startScan() {
        state = .scanning
        readValue = nil
        centralManager.scanForPeripherals(withServices: [serviceUUID])
        // CBCentralManagerScanOptionAllowDuplicatesKey to update RSSI
    }

    func stopScan() {
        guard state == .scanning else {
            return
        }
        state = .ready
        centralManager.stopScan()
    }

    func connect(identifier: UUID) {
        guard let peripheral = centralManager.retrievePeripherals(withIdentifiers: [identifier]).first else {
            return
        }
        state = .connecting(peripheral: .init(peripheral))
        centralManager.connect(peripheral, options: nil)
    }

    func reconnect(identifiers: [UUID]) -> Bool {
        guard let peripheral = centralManager.retrievePeripherals(withIdentifiers: identifiers).first else {
            return false
        }
        centralManager.connect(peripheral, options: nil)
        return true
    }

    func write(value: Value) {
        guard let remotePeripheral, let remoteCharacteristic else {
            return
        }
        // Write value to characteristic
        let ptr = UnsafeMutablePointer<Value>.allocate(capacity: 1)
        ptr.pointee = value.littleEndian
        let data = Data(bytes: ptr, count: MemoryLayout<Value>.size)
        ptr.deallocate()
        remotePeripheral.writeValue(data, for: remoteCharacteristic, type: .withResponse)
    }
}
