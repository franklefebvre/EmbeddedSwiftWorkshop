import SwiftUI
import CoreBluetooth

struct ContentView: View {
    private static let serviceUUID = CBUUID(string: "11808D84-EC34-4D06-AAB7-01F715D88F90")
    private static let characteristicUUID = CBUUID(string: "D02E9282-89EF-4051-AAF0-C2C01B43DF4C")

    @State private var client = BluetoothConnectionManager(serviceUUID: serviceUUID, characteristicUUID: characteristicUUID, valueType: UInt8.self)
    @State private var sliderValue: Double = 0

    var body: some View {
        VStack {
            switch client.state {
//            case .unknown:
//                EmptyView()
            case .unavailable(let message):
                Text(message)
            case .unknown, .ready:
                Button("Scan for devices") {
                    client.startScan()
                }
            case .scanning:
                ProgressView()
                Button("Stop scanning") {
                    client.stopScan()
                }
            case .discovered(let peripherals):
                ForEach(peripherals) { peripheral in
                    Button(peripheral.name ?? "Unknown") {
                        client.connect(identifier: peripheral.uuid)
                    }
                }
            case .connecting(peripheral: let peripheral):
                ProgressView()
                if let name = peripheral.name {
                    Text("Connecting to: \(name)")
                } else {
                    Text("Connecting")
                }
            case .connected(let peripheral):
                Text("Connected to: \(peripheral.name ?? "Unknown")")
                Group {
                    if client.readValue != nil {
                        Text("Value: \(Int(sliderValue))")
                        Slider(value: $sliderValue, in: 0...100, step: 1) { _ in }
                    } else {
                        Text("No value yet")
                    }
                }
                .onAppear() {
                    sliderValue = Double(client.readValue ?? 0)
                }
                .onChange(of: client.readValue) {
                    if let value = client.readValue {
                        sliderValue = Double(value)
                    }
                }
                .onChange(of: sliderValue) {
                    let value = UInt8(sliderValue)
                    if value != client.readValue {
                        client.write(value: value)
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
