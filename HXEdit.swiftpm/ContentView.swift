import SwiftUI

struct ContentView: View {
    @EnvironmentObject var midi: MIDIController

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    connectionCard
                    actionButtons
                    if !midi.lastResponse.isEmpty {
                        responseCard
                    }
                }
                .padding()
            }
            .navigationTitle("HX Edit")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Subviews

    private var connectionCard: some View {
        VStack(spacing: 14) {
            Image(systemName: midi.isConnected ? "cable.connector" : "cable.connector.slash")
                .font(.system(size: 72))
                .foregroundStyle(midi.isConnected ? .green : .secondary)
                .symbolEffect(.pulse, isActive: !midi.isConnected)

            Text(midi.statusMessage)
                .font(.headline)
                .multilineTextAlignment(.center)

            Button {
                midi.scanForHXStomp()
            } label: {
                Label("Scan Again", systemImage: "arrow.clockwise")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var actionButtons: some View {
        VStack(spacing: 14) {
            // Standard MIDI command — always shown
            commandButton(
                title: "Request Device Info",
                subtitle: "Universal MIDI Identity Request",
                icon: "info.circle.fill",
                tint: .blue
            ) {
                midi.requestDeviceInfo()
            }

            // Proprietary Line 6 command
            commandButton(
                title: "Get Current Preset Name",
                subtitle: "Line 6 proprietary SysEx",
                icon: "music.note.list",
                tint: .purple
            ) {
                midi.requestCurrentPresetName()
            }
        }
    }

    private func commandButton(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(midi.isConnected ? tint : .secondary)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!midi.isConnected)
    }

    private var responseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Last Response", systemImage: "arrow.down.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text(midi.lastResponse)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    ContentView()
        .environmentObject(MIDIController())
}
