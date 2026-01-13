import SwiftUI

enum MainTab: String, CaseIterable {
    case scripts = "Scripts"
    case logs = "Logs"
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .scripts: return "list.bullet.rectangle"
        case .logs: return "doc.text"
        case .settings: return "gear"
        }
    }
}

struct MainWindowView: View {
    @EnvironmentObject var scriptManager: ScriptManager
    @State private var selectedTab: MainTab = .scripts
    @State private var isAddingScript = false
    @State private var editingScript: Script?
    @State private var selectedScriptForLog: Script?
    
    let initialTab: MainTab
    let initialAction: MainWindowAction
    
    init(initialTab: MainTab = .scripts, initialAction: MainWindowAction = .none) {
        self.initialTab = initialTab
        self.initialAction = initialAction
        _selectedTab = State(initialValue: initialTab)
        
        if case .addScript = initialAction {
            _isAddingScript = State(initialValue: true)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            tabHeader
            
            Divider()
            
            tabContent
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear {
            handleInitialAction()
        }
    }
    
    private var tabHeader: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 8) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var tabContent: some View {
        ZStack {
            ScriptsTabView(
                isAddingScript: $isAddingScript,
                editingScript: $editingScript,
                onViewLog: { script in
                    selectedScriptForLog = script
                    selectedTab = .logs
                }
            )
            .opacity(selectedTab == .scripts ? 1 : 0)
            .allowsHitTesting(selectedTab == .scripts)
            
            LogsTabView(selectedScript: $selectedScriptForLog)
                .opacity(selectedTab == .logs ? 1 : 0)
                .allowsHitTesting(selectedTab == .logs)
            
            SettingsTabView()
                .opacity(selectedTab == .settings ? 1 : 0)
                .allowsHitTesting(selectedTab == .settings)
        }
    }
    
    private func handleInitialAction() {
        switch initialAction {
        case .addScript:
            selectedTab = .scripts
            isAddingScript = true
        case .viewLog(let script):
            selectedTab = .logs
            selectedScriptForLog = script
        case .editScript(let script):
            selectedTab = .scripts
            editingScript = script
        case .none:
            break
        }
    }
}

struct TabButton: View {
    let tab: MainTab
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(minWidth: 100)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(backgroundStyle)
            .foregroundColor(foregroundStyle)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .shadow(color: isSelected ? Color.black.opacity(0.1) : Color.clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.1), value: isHovering)
    }
    
    private var backgroundStyle: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        } else if isHovering {
            return Color.gray.opacity(0.1)
        } else {
            return Color.gray.opacity(0.05)
        }
    }
    
    private var foregroundStyle: Color {
        isSelected ? .accentColor : .secondary
    }
}

enum MainWindowAction {
    case none
    case addScript
    case editScript(Script)
    case viewLog(Script)
}

struct ScriptsTabView: View {
    @EnvironmentObject var scriptManager: ScriptManager
    @Binding var isAddingScript: Bool
    @Binding var editingScript: Script?
    var onViewLog: (Script) -> Void
    
    var body: some View {
        HSplitView {
            scriptListView
                .frame(minWidth: 300)
            
            scriptDetailView
                .frame(minWidth: 350)
        }
    }
    
    private var scriptListView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Scripts")
                    .font(.headline)
                Spacer()
                Text("\(scriptManager.runningCount)/\(scriptManager.scripts.count) running")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Divider()
            
            if scriptManager.scripts.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(scriptManager.scripts) { script in
                        ScriptListRow(
                            script: script,
                            status: scriptManager.statuses[script.id] ?? .stopped,
                            isSelected: editingScript?.id == script.id,
                            onSelect: { editingScript = script; isAddingScript = false },
                            onStart: { scriptManager.startScript(script) },
                            onStop: { scriptManager.stopScript(script) },
                            onViewLog: { onViewLog(script) }
                        )
                    }
                    .onDelete(perform: deleteScripts)
                }
                .listStyle(.inset)
            }
            
            Divider()
            
            HStack {
                Button(action: { 
                    isAddingScript = true
                    editingScript = nil
                }) {
                    Label("Add Script", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button("Start All") {
                    scriptManager.startAllScripts()
                }
                .disabled(scriptManager.scripts.isEmpty)
                
                Button("Stop All") {
                    scriptManager.stopAllScripts()
                }
                .disabled(scriptManager.runningCount == 0)
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No scripts yet")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Click 'Add Script' to get started")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var scriptDetailView: some View {
        if isAddingScript {
            ScriptFormView(
                mode: .add,
                onSave: { script in
                    scriptManager.addScript(script)
                    isAddingScript = false
                    editingScript = script
                },
                onCancel: {
                    isAddingScript = false
                }
            )
        } else if let script = editingScript {
            ScriptFormView(
                mode: .edit(script),
                onSave: { updated in
                    scriptManager.updateScript(updated)
                    editingScript = updated
                },
                onCancel: {
                    editingScript = nil
                },
                onDelete: {
                    scriptManager.deleteScript(script)
                    editingScript = nil
                }
            )
        } else {
            VStack {
                Spacer()
                Image(systemName: "sidebar.right")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Select a script to edit")
                    .foregroundColor(.secondary)
                Text("or click 'Add Script' to create new")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
    
    private func deleteScripts(at offsets: IndexSet) {
        for index in offsets {
            let script = scriptManager.scripts[index]
            scriptManager.deleteScript(script)
            if editingScript?.id == script.id {
                editingScript = nil
            }
        }
    }
}

struct ScriptListRow: View {
    let script: Script
    let status: ScriptStatus
    let isSelected: Bool
    let onSelect: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void
    let onViewLog: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status.icon)
                .font(.caption)
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(script.name)
                        .fontWeight(.medium)
                    
                    if script.isAutoStart {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
                Text(script.command)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
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
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
    }
    
    private var statusColor: Color {
        switch status {
        case .stopped: return .gray
        case .running: return .green
        case .crashed: return .red
        }
    }
}

enum ScriptFormMode {
    case add
    case edit(Script)
}

struct ScriptFormView: View {
    let mode: ScriptFormMode
    let onSave: (Script) -> Void
    let onCancel: () -> Void
    var onDelete: (() -> Void)?
    
    @State private var name: String = ""
    @State private var command: String = ""
    @State private var workingDirectory: String = ""
    @State private var isAutoStart: Bool = false
    @State private var showDeleteConfirm = false
    
    init(mode: ScriptFormMode, onSave: @escaping (Script) -> Void, onCancel: @escaping () -> Void, onDelete: (() -> Void)? = nil) {
        self.mode = mode
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        
        if case .edit(let script) = mode {
            _name = State(initialValue: script.name)
            _command = State(initialValue: script.command)
            _workingDirectory = State(initialValue: script.workingDirectory)
            _isAutoStart = State(initialValue: script.isAutoStart)
        }
    }
    
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "Edit Script" : "New Script")
                    .font(.headline)
                Spacer()
            }
            .padding()
            
            Divider()
            
            Form {
                Section("Script Name") {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("Command") {
                    TextEditor(text: $command)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    Text("e.g., npm run dev, ./scripts/start.sh, gkg server start")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Working Directory") {
                    HStack {
                        TextField("Path (leave empty for home)", text: $workingDirectory)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Browse...") {
                            selectDirectory()
                        }
                    }
                }
                
                Section("Options") {
                    Toggle("Auto-start when app launches", isOn: $isAutoStart)
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            HStack {
                if isEditing, let onDelete = onDelete {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                
                Button("Save") {
                    saveScript()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || command.isEmpty)
            }
            .padding()
        }
        .alert("Delete Script?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private func saveScript() {
        switch mode {
        case .add:
            let script = Script(
                name: name,
                command: command,
                workingDirectory: workingDirectory,
                isAutoStart: isAutoStart
            )
            onSave(script)
            
        case .edit(let existingScript):
            var updated = existingScript
            updated.name = name
            updated.command = command
            updated.workingDirectory = workingDirectory
            updated.isAutoStart = isAutoStart
            onSave(updated)
        }
    }
    
    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            workingDirectory = url.path
        }
    }
}

struct LogsTabView: View {
    @EnvironmentObject var scriptManager: ScriptManager
    @Binding var selectedScript: Script?
    @State private var autoScroll = true
    @State private var searchText = ""
    
    private var logStore: LogStore? {
        guard let script = selectedScript else { return nil }
        return scriptManager.logs[script.id]
    }
    
    private var filteredEntries: [LogEntry] {
        guard let store = logStore else { return [] }
        
        if searchText.isEmpty {
            return store.entries
        }
        
        return store.entries.filter {
            $0.message.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            toolbarView
            
            Divider()
            
            if selectedScript == nil {
                emptyStateView
            } else {
                logContentView
            }
            
            Divider()
            
            footerView
        }
    }
    
    private var toolbarView: some View {
        HStack(spacing: 12) {
            Picker("Script", selection: $selectedScript) {
                Text("Select a script").tag(nil as Script?)
                ForEach(scriptManager.scripts) { script in
                    HStack {
                        Image(systemName: (scriptManager.statuses[script.id] ?? .stopped).icon)
                        Text(script.name)
                    }
                    .tag(script as Script?)
                }
            }
            .frame(width: 200)
            
            if let script = selectedScript {
                let status = scriptManager.statuses[script.id] ?? .stopped
                HStack(spacing: 4) {
                    Image(systemName: status.icon)
                        .foregroundColor(statusColor(for: status))
                    Text(status.displayName)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 150)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
            
            Toggle("Auto-scroll", isOn: $autoScroll)
                .toggleStyle(.checkbox)
            
            Button(action: {
                if let script = selectedScript {
                    scriptManager.clearLog(for: script)
                }
            }) {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(selectedScript == nil)
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Select a script to view logs")
                .font(.title3)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var logContentView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(filteredEntries) { entry in
                        LogEntryRow(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onChange(of: logStore?.entries.count ?? 0) { oldValue, newValue in
                if autoScroll, let lastEntry = filteredEntries.last {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var footerView: some View {
        HStack {
            Text("\(filteredEntries.count) entries")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !searchText.isEmpty {
                Text("(filtered)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let script = selectedScript {
                let status = scriptManager.statuses[script.id] ?? .stopped
                
                if status == .running {
                    Button("Stop") {
                        scriptManager.stopScript(script)
                    }
                    
                    Button("Restart") {
                        scriptManager.restartScript(script)
                    }
                } else {
                    Button("Start") {
                        scriptManager.startScript(script)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
    }
    
    private func statusColor(for status: ScriptStatus) -> Color {
        switch status {
        case .stopped: return .gray
        case .running: return .green
        case .crashed: return .red
        }
    }
}

struct SettingsTabView: View {
    @EnvironmentObject var scriptManager: ScriptManager
    @State private var showingExportSuccess = false
    @State private var showingImportError = false
    @State private var importErrorMessage = ""
    
    var body: some View {
        Form {
            Section("Statistics") {
                LabeledContent("Total Scripts") {
                    Text("\(scriptManager.scripts.count)")
                }
                
                LabeledContent("Running") {
                    Text("\(scriptManager.runningCount)")
                        .foregroundColor(.green)
                }
                
                LabeledContent("Auto-start Scripts") {
                    Text("\(scriptManager.scripts.filter { $0.isAutoStart }.count)")
                }
            }
            
            Section("Keyboard Shortcuts") {
                Text("⌘N - Add new script")
                Text("⌘⇧R - Start all scripts")
                Text("⌘. - Stop all scripts")
                Text("⌘, - Open Settings")
                Text("⌘W - Close window")
                Text("⌘Q - Quit app")
            }
            
            Section("Backup & Restore") {
                HStack {
                    Button("Export Configuration") {
                        exportConfiguration()
                    }
                    
                    Button("Import Configuration") {
                        importConfiguration()
                    }
                }
                
                Text("Export your scripts to a JSON file for backup or sharing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("About") {
                LabeledContent("Version") {
                    Text("1.0.0")
                }
                
                Text("ScriptRunner - A simple menu bar app to manage and run your scripts in the background.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Export Successful", isPresented: $showingExportSuccess) {
            Button("OK", role: .cancel) {}
        }
        .alert("Import Failed", isPresented: $showingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
    }
    
    private func exportConfiguration() {
        guard let data = scriptManager.exportConfiguration() else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "ScriptRunner-config.json"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                showingExportSuccess = true
            } catch {
                importErrorMessage = error.localizedDescription
                showingImportError = true
            }
        }
    }
    
    private func importConfiguration() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                try scriptManager.importConfiguration(from: data)
            } catch {
                importErrorMessage = error.localizedDescription
                showingImportError = true
            }
        }
    }
}

struct LogEntryRow: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.formattedTimestamp)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(entry.isError ? .red : .primary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    MainWindowView()
        .environmentObject(ScriptManager.shared)
}
