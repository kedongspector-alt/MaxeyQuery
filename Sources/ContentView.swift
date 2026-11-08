import SwiftUI

struct ContentView: View {

    @State private var processes: [RunningProcess] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var lastScan: Date?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {

                HStack {
                    VStack(alignment: .leading) {
                        Text("Process Explorer")
                            .font(.title2.bold())

                        Text("iOS host process enumeration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "cpu")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)

                HStack {
                    statCard(
                        title: "Processes",
                        value: "\(processes.count)"
                    )

                    statCard(
                        title: "Last scan",
                        value: lastScan.map {
                            $0.formatted(
                                date: .omitted,
                                time: .shortened
                            )
                        } ?? "Never"
                    )
                }
                .padding(.horizontal)

                Button {
                    scan()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(isLoading ? "Scanning..." : "Scan Processes")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoading)
                .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                List(processes) { process in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(process.name)
                                .font(.body.weight(.medium))

                            Text("PID \(process.id)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .listStyle(.plain)

                Text("API results are subject to iOS sandbox restrictions.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 6)
            }
            .padding(.top)
            .navigationTitle("MaxeyQuery")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func scan() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let result = ProcessEnumerator.enumerate()

            DispatchQueue.main.async {
                processes = result.processes
                errorMessage = result.error
                lastScan = Date()
                isLoading = false
            }
        }
    }
}

#Preview {
    ContentView()
}
