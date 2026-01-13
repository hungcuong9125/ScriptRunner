import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var scriptManager: ScriptManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            if scriptManager.scripts.isEmpty {
                emptyStateView
            } else {
                scriptListView
            }
            
            Divider()
            
            footerView
        }
        .frame(width: 280)
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "terminal.fill")
                .foregroundColor(.accentColor)
            Text("ScriptRunner")
                .font(.headline)
            Spacer()
            Text("\(scriptManager.runningCount)/\(scriptManager.scripts.count)")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(scriptManager.runningCount > 0 ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.badge.plus")
                .font(.title)
                .foregroundColor(.secondary)
            Text("No scripts")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Add Script") {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    WindowManager.shared.openMainWindow(
                        tab: .scripts,
                        action: .addScript,
                        scriptManager: scriptManager
                    )
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var scriptListView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(scriptManager.scripts) { script in
                    QuickScriptRow(
                        script: script,
                        status: scriptManager.statuses[script.id] ?? .stopped,
                        onStart: { scriptManager.startScript(script) },
                        onStop: { scriptManager.stopScript(script) },
                        onViewLog: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                WindowManager.shared.openMainWindow(
                                    tab: .logs,
                                    action: .viewLog(script),
                                    scriptManager: scriptManager
                                )
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 250)
    }
    
    private var footerView: some View {
        HStack(spacing: 6) {
            Button(action: {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    WindowManager.shared.openMainWindow(
                        tab: .scripts,
                        action: .addScript,
                        scriptManager: scriptManager
                    )
                }
            }) {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("n", modifiers: .command)
            
            Divider()
                .frame(height: 16)
            
            Button(action: {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    WindowManager.shared.openMainWindow(
                        tab: .settings,
                        action: .none,
                        scriptManager: scriptManager
                    )
                }
            }) {
                Label("Settings", systemImage: "gear")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(",", modifiers: .command)
            
            Spacer()
            
            if !scriptManager.scripts.isEmpty {
                Button(action: { scriptManager.startAllScripts() }) {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.borderless)
                .help("Start All")
                .keyboardShortcut("r", modifiers: [.command, .shift])
                
                Button(action: { scriptManager.stopAllScripts() }) {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.borderless)
                .help("Stop All")
                .keyboardShortcut(".", modifiers: .command)
            }
            
            Divider()
                .frame(height: 16)
            
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit")
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct QuickScriptRow: View {
    let script: Script
    let status: ScriptStatus
    let onStart: () -> Void
    let onStop: () -> Void
    let onViewLog: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(script.name)
                .font(.subheadline)
                .lineLimit(1)
            
            if script.isAutoStart {
                Image(systemName: "bolt.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            
            Spacer()
            
            if isHovering {
                HStack(spacing: 4) {
                    if status == .running {
                        Button(action: onStop) {
                            Image(systemName: "stop.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    } else {
                        Button(action: onStart) {
                            Image(systemName: "play.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    Button(action: onViewLog) {
                        Image(systemName: "doc.text")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                Text(status.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isHovering ? Color.gray.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .onHover { isHovering = $0 }
    }
    
    private var statusColor: Color {
        switch status {
        case .stopped: return .gray
        case .running: return .green
        case .crashed: return .red
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(ScriptManager.shared)
}
