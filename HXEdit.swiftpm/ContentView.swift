import SwiftUI

struct ContentView: View {
    @EnvironmentObject var midi: MIDIController

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statusCard
                    actionButtons
                    if !midi.lastResponse.isEmpty {
                        responsePanel
                    }
                    protocolNote
                }
                .padding()
            }
            .navigationTitle("HX Edit")
        }
    }

    // MARK: - Status

    private var statusCard: some View {
        HStack(spacing: 16) {
            Image(systemName: midi.isConnected ? "guitars.fill" : "guitars")
                .font(.system(size: 36))
                .foregroundStyle(midi.isConnected ? .green : .secondary)
                .symbolEffect(.pulse, isActive: midi.isConnected)

            VStack(alignment: .leading, spacing: 4) {
                Text(midi.isConnected ? "Connected" : "Not Connected")
                    .font(.headline)
                Text(midi.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Scan Again") { midi.scanForHXStomp() }
                .buttonStyle(.bordered)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                midi.requestDeviceInfo()
            } label: {
                Label("Request Device Info (MIDI Identity)", systemImage: "info.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!midi.isConnected)

            Button {
                midi.showPresetListRequest()
            } label: {
                Label("Show OPEN_PRESETS Packet", systemImage: "list.bullet.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Response

    private var responsePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Last response / packet")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(midi.lastResponse)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Note about transport

    private var protocolNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("About the proprietary protocol", systemImage: "exclamationmark.bubble")
                .font(.footnote.weight(.semibold))
            Text("The HX proprietary editor protocol travels over USB bulk transfers on a vendor-specific interface (VID 0x0E41 / PID 0x4253), not MIDI SysEx. CoreMIDI can carry the standard MIDI Identity Request, but the OPEN_PRESETS packet shown above must be sent through a USB host transport (DriverKit / IOUSBHost). See Reference/docs/protocol/ for the full spec.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    ContentView()
        .environmentObject(MIDIController())
}
