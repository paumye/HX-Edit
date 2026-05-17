import Foundation
import CoreMIDI

/// Manages the connection to an HX Stomp.
///
/// Two transports coexist on this device:
///
/// 1. **Class-compliant USB-MIDI** — exposes program/control change, MIDI Clock,
///    and Universal SysEx. CoreMIDI handles this. Useful for the Identity Request
///    proof-of-concept and for live performance MIDI.
///
/// 2. **Vendor-specific USB bulk interface** — carries the proprietary editor
///    protocol (preset list, patch dump, deep parameter edits). This is NOT
///    MIDI and cannot be transported through CoreMIDI. See `HXProtocol` for the
///    documented packet bytes; an actual implementation requires a USB host
///    transport (`IOUSBHost` on macOS; `DriverKit` / external accessory on iPadOS).
///
/// This controller wires up the CoreMIDI side and exposes the documented
/// proprietary packets as `Data` so they can be wired to a USB transport later.
final class MIDIController: ObservableObject {

    // MARK: - Published state

    @Published var isConnected = false
    @Published var deviceName: String = ""
    @Published var lastResponse: String = ""
    @Published var statusMessage: String = "Not connected"

    // MARK: - CoreMIDI state

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var outputPort = MIDIPortRef()
    private var destination: MIDIEndpointRef = 0

    // MARK: - Lifecycle

    func setupMIDI() {
        let clientStatus = MIDIClientCreateWithBlock("HXEdit" as CFString, &client) { [weak self] _ in
            DispatchQueue.main.async { self?.scanForHXStomp() }
        }
        guard clientStatus == noErr else {
            statusMessage = "MIDIClientCreate failed (\(clientStatus))"
            return
        }

        MIDIInputPortCreateWithBlock(client, "HXEdit.in" as CFString, &inputPort) { [weak self] pktList, _ in
            self?.handle(packetList: pktList)
        }
        MIDIOutputPortCreate(client, "HXEdit.out" as CFString, &outputPort)

        scanForHXStomp()
    }

    // MARK: - Discovery

    func scanForHXStomp() {
        destination = 0
        var found = false

        let destCount = MIDIGetNumberOfDestinations()
        for i in 0..<destCount {
            let endpoint = MIDIGetDestination(i)
            let name = endpointName(endpoint)
            if name.lowercased().contains("hx stomp") {
                destination = endpoint
                deviceName = name
                found = true
                break
            }
        }

        let srcCount = MIDIGetNumberOfSources()
        for i in 0..<srcCount {
            let source = MIDIGetSource(i)
            if endpointName(source).lowercased().contains("hx stomp") {
                MIDIPortConnectSource(inputPort, source, nil)
            }
        }

        isConnected = found
        statusMessage = found ? "Connected to \(deviceName)" : "HX Stomp not detected"
    }

    // MARK: - POC 1: Universal MIDI Identity Request (CoreMIDI-safe)

    /// Sends a standard MIDI Identity Request. The HX Stomp responds with the
    /// Line 6 manufacturer ID (`00 01 0C`) and firmware version. This *does*
    /// travel over CoreMIDI and is safe to send to any class-compliant device.
    func requestDeviceInfo() {
        let identityRequest = Data([0xF0, 0x7E, 0x7F, 0x06, 0x01, 0xF7])
        sendSysEx(identityRequest)
        statusMessage = "Sent MIDI Identity Request"
    }

    // MARK: - POC 2: Proprietary preset list (USB bulk only)

    /// The documented proprietary request to begin streaming the preset list.
    ///
    /// Returns the **OPEN_PRESETS** packet (`seq=0x06`) from
    /// `Reference/docs/protocol/presets/list.md` — Phase 1 of the preset-list
    /// operation. The full operation also requires the 5-packet session
    /// handshake (`HXProtocol.handshakeSequence`) beforehand, then OPEN_STREAM
    /// and the chunk-request loop afterward.
    ///
    /// IMPORTANT: this packet is NOT MIDI SysEx. It is a binary frame that
    /// must be written to USB bulk endpoint `0x01` on the device's
    /// vendor-specific interface. Sending it through CoreMIDI will not reach
    /// the proprietary endpoint. This function exposes the correct bytes so
    /// the USB transport layer (to be added) can use them directly.
    func presetListRequestPacket() -> Data {
        HXProtocol.openPresets
    }

    /// Convenience: pretty-prints the documented OPEN_PRESETS bytes into the
    /// `lastResponse` panel so the user can verify them against the docs.
    func showPresetListRequest() {
        let packet = presetListRequestPacket()
        lastResponse = packet.hexString()
        statusMessage = "OPEN_PRESETS packet ready (USB bulk transport required)"
    }

    // MARK: - Sending helpers

    private func sendSysEx(_ data: Data) {
        guard destination != 0 else {
            statusMessage = "No destination — connect HX Stomp first"
            return
        }
        let packetSize = MemoryLayout<MIDIPacketList>.size + data.count
        let pktListPtr = UnsafeMutablePointer<MIDIPacketList>.allocate(capacity: packetSize)
        defer { pktListPtr.deallocate() }

        let pkt = MIDIPacketListInit(pktListPtr)
        _ = data.withUnsafeBytes { raw -> UnsafeMutablePointer<MIDIPacket>? in
            guard let base = raw.baseAddress else { return nil }
            return MIDIPacketListAdd(pktListPtr, packetSize, pkt, 0, data.count,
                                     base.assumingMemoryBound(to: UInt8.self))
        }

        let status = MIDISend(outputPort, destination, pktListPtr)
        if status != noErr {
            statusMessage = "MIDISend failed (\(status))"
        }
    }

    // MARK: - Receiving

    private func handle(packetList: UnsafePointer<MIDIPacketList>) {
        let pktList = packetList.pointee
        var packet = pktList.packet
        for _ in 0..<pktList.numPackets {
            let length = Int(packet.length)
            let bytes = withUnsafeBytes(of: packet.data) { rawBuf in
                Array(rawBuf.prefix(length))
            }
            let hex = Data(bytes).hexString()
            DispatchQueue.main.async { self.lastResponse = hex }
            packet = MIDIPacketNext(&packet).pointee
        }
    }

    // MARK: - Utilities

    private func endpointName(_ endpoint: MIDIEndpointRef) -> String {
        var name: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
        guard status == noErr, let n = name?.takeRetainedValue() as String? else { return "" }
        return n
    }
}

private extension Data {
    func hexString() -> String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
