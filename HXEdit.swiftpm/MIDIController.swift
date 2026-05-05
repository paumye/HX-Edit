import CoreMIDI
import Foundation

/// Manages discovery, connection, and communication with the Line 6 HX Stomp via USB-MIDI.
class MIDIController: ObservableObject {
    @Published var isConnected = false
    @Published var statusMessage = "Plug in your HX Stomp via USB-C"
    @Published var lastResponse = ""

    private var client = MIDIClientRef()
    private var outputPort = MIDIPortRef()
    private var inputPort = MIDIPortRef()
    private var hxDestination = MIDIEndpointRef()

    init() {
        setupMIDI()
    }

    // MARK: - Setup

    private func setupMIDI() {
        let status = MIDIClientCreateWithBlock("HXEdit" as CFString, &client) { [weak self] notifPtr in
            let id = notifPtr.pointee.messageID
            if id == .msgObjectAdded || id == .msgObjectRemoved || id == .msgSetupChanged {
                DispatchQueue.main.async { self?.scanForHXStomp() }
            }
        }
        guard status == noErr else {
            DispatchQueue.main.async { self.statusMessage = "MIDI init failed (\(status))" }
            return
        }

        MIDIOutputPortCreate(client, "HXEdit.Out" as CFString, &outputPort)

        MIDIInputPortCreateWithBlock(client, "HXEdit.In" as CFString, &inputPort) { [weak self] packetListPtr, _ in
            self?.receivePackets(packetListPtr)
        }

        scanForHXStomp()
    }

    // MARK: - Device Discovery

    /// Scans all CoreMIDI devices for one whose name contains "HX Stomp".
    func scanForHXStomp() {
        hxDestination = 0
        var found = false

        for i in 0..<MIDIGetNumberOfDevices() {
            let device = MIDIGetDevice(i)
            var cfName: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(device, kMIDIPropertyName, &cfName)
            guard let name = cfName?.takeRetainedValue() as String?,
                  name.lowercased().contains("hx stomp") else { continue }

            for j in 0..<MIDIDeviceGetNumberOfEntities(device) {
                let entity = MIDIDeviceGetEntity(device, j)
                for k in 0..<MIDIEntityGetNumberOfSources(entity) {
                    MIDIPortConnectSource(inputPort, MIDIEntityGetSource(entity, k), nil)
                }
                if MIDIEntityGetNumberOfDestinations(entity) > 0 {
                    hxDestination = MIDIEntityGetDestination(entity, 0)
                    found = true
                }
            }
        }

        isConnected = found
        statusMessage = found
            ? "Connected to HX Stomp"
            : "HX Stomp not found — plug in via USB-C"
    }

    // MARK: - Receive

    private func receivePackets(_ listPtr: UnsafePointer<MIDIPacketList>) {
        var packet = listPtr.pointee.packet
        for _ in 0..<listPtr.pointee.numPackets {
            let length = Int(packet.length)
            let bytes = withUnsafeBytes(of: packet.data) { Array($0.prefix(length)) }
            let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
            DispatchQueue.main.async { self.lastResponse = hex }
            packet = MIDIPacketNext(&packet).pointee
        }
    }

    // MARK: - Proof-of-Concept Commands

    /// Universal MIDI Identity Request (MIDI spec, completely safe on all devices).
    /// The HX Stomp will respond with its Line 6 manufacturer ID (00 01 0C)
    /// and firmware version, confirming the USB-MIDI connection.
    func requestDeviceInfo() {
        // F0 7E 7F 06 01 F7  — Universal SysEx, Identity Request, channel 0x7F (all)
        send(sysex: [0xF0, 0x7E, 0x7F, 0x06, 0x01, 0xF7])
    }

    /// Requests the name of the currently loaded preset using the Line 6 proprietary
    /// SysEx protocol reverse-engineered from HX Edit traffic captures.
    ///
    /// Frame layout:
    ///   F0  — SysEx start
    ///   00 01 0C  — Line 6 manufacturer ID
    ///   00  — device ID (0x00 = device 1; 0x7F = broadcast)
    ///   0C 00  — model family / product: HX Stomp
    ///   01  — command class: object request
    ///   04  — object type: current program name
    ///   00 00  — object index (0 = current)
    ///   F7  — SysEx end
    func requestCurrentPresetName() {
        send(sysex: [
            0xF0,
            0x00, 0x01, 0x0C,   // Line 6 manufacturer ID
            0x00,               // device ID
            0x0C, 0x00,         // HX Stomp model
            0x01,               // command class: object request
            0x04,               // object: current program name
            0x00, 0x00,         // index
            0xF7
        ])
    }

    // MARK: - Send Helpers

    private func send(sysex bytes: [UInt8]) {
        guard hxDestination != 0 else {
            DispatchQueue.main.async { self.statusMessage = "Not connected — cannot send" }
            return
        }

        // Allocate a properly-aligned buffer large enough for MIDIPacketList + payload.
        let bufSize = MemoryLayout<MIDIPacketList>.size + bytes.count
        let rawBuf = UnsafeMutableRawBufferPointer.allocate(
            byteCount: bufSize,
            alignment: MemoryLayout<MIDIPacketList>.alignment
        )
        defer { rawBuf.deallocate() }

        rawBuf.initializeMemory(as: UInt8.self, repeating: 0)
        let listPtr = rawBuf.baseAddress!.assumingMemoryBound(to: MIDIPacketList.self)
        var packetPtr = MIDIPacketListInit(listPtr)
        packetPtr = MIDIPacketListAdd(listPtr, bufSize, packetPtr, 0, bytes.count, bytes)
        guard packetPtr != nil else { return }

        MIDISend(outputPort, hxDestination, listPtr)
    }
}
