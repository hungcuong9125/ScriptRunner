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
    @State private var selectedScriptId: UUID?
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
    
    private var selectedScript: Script? {
        guard let id = selectedScriptId else { return nil }
        return scriptManager.scripts.first { $0.id == id }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            tabHeader
            
            Divider()
            
            tabContent
        }
        .frame(minWidth: 1000, minHeight: 650)

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
                selectedScriptId: $selectedScriptId,
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
            selectedScriptId = script.id
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
        .pointingHandCursor()
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
    @Binding var selectedScriptId: UUID?
    var onViewLog: (Script) -> Void
    
    private var selectedScript: Script? {
        guard let id = selectedScriptId else { return nil }
        return scriptManager.scripts.first { $0.id == id }
    }
    
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
                List(selection: $selectedScriptId) {
                    ForEach(scriptManager.scripts) { script in
                        ScriptListRow(
                            script: script,
                            status: scriptManager.statuses[script.id] ?? .stopped,
                            isSelected: selectedScriptId == script.id,
                            onStart: { scriptManager.startScript(script) },
                            onStop: { scriptManager.stopScript(script) },
                            onViewLog: { onViewLog(script) }
                        )
                        .tag(script.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedScriptId = script.id
                            isAddingScript = false
                        }
                    }
                    .onDelete(perform: deleteScripts)
                }
                .listStyle(.inset)
            }
            
            Divider()
            
            HStack {
                Button(action: { 
                    isAddingScript = true
                    selectedScriptId = nil
                }) {
                    Label("Add Script", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .pointingHandCursor()
                
                Spacer()
                
                Button("Start All") {
                    scriptManager.startAllScripts()
                }
                .disabled(scriptManager.scripts.isEmpty)
                .pointingHandCursor()
                
                Button("Stop All") {
                    scriptManager.stopAllScripts()
                }
                .disabled(scriptManager.runningCount == 0)
                .pointingHandCursor()
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
                    selectedScriptId = script.id
                },
                onCancel: {
                    isAddingScript = false
                }
            )
        } else if let script = selectedScript {
            ScriptDetailView(
                script: script,
                status: scriptManager.statuses[script.id] ?? .stopped,
                onSave: { updated in
                    scriptManager.updateScript(updated)
                },
                onDelete: {
                    scriptManager.deleteScript(script)
                    selectedScriptId = nil
                },
                onStart: {
                    scriptManager.startScript(script)
                },
                onStop: {
                    scriptManager.stopScript(script)
                },
                onForceKill: {
                    scriptManager.forceKillScript(script)
                },
                onViewLog: {
                    onViewLog(script)
                }
            )
            .id(script.id)
        } else {

            VStack {
                Spacer()
                Image(systemName: "sidebar.right")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Select a script to view details")
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
            if selectedScriptId == script.id {
                selectedScriptId = nil
            }
        }
    }
}

struct ScriptListRow: View {
    let script: Script
    let status: ScriptStatus
    let isSelected: Bool
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
                    .help("Stop script")
                    .pointingHandCursor()
                } else {
                    Button(action: onStart) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Start script")
                    .pointingHandCursor()
                }
                
                Button(action: onViewLog) {
                    Image(systemName: "doc.text")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("View logs")
                .pointingHandCursor()
            }

        }
        .padding(.vertical, 4)
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

struct ScriptDetailView: View {
    let script: Script
    let status: ScriptStatus
    let onSave: (Script) -> Void
    let onDelete: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void
    let onForceKill: () -> Void
    let onViewLog: () -> Void
    
    @State private var isEditing = false
    @State private var editName: String = ""
    @State private var editCommand: String = ""
    @State private var editWorkingDirectory: String = ""
    @State private var editIsAutoStart: Bool = false
    @State private var editKillCommand: String = ""
    @State private var showDeleteConfirm = false
    @State private var showForceKillConfirm = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            if isEditing {
                editFormView
            } else {
                detailView
            }
            
            Divider()
            
            footerView
        }
        .onAppear {
            resetEditFields()
        }
        .onChange(of: script.id) { _, _ in
            isEditing = false
            resetEditFields()
        }
    }
    
    private var headerView: some View {
        HStack {
            Text(isEditing ? "Edit Script" : "Script Details")
                .font(.headline)
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: status.icon)
                    .foregroundColor(statusColor)
                Text(status.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private var detailView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailSection(title: "Script Name") {
                    Text(script.name)
                        .font(.title3)
                        .fontWeight(.medium)
                }
                
                DetailSection(title: "Command") {
                    Text(script.command)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                        .textSelection(.enabled)
                }
                
                DetailSection(title: "Working Directory") {
                    Text(script.workingDirectory.isEmpty ? "~ (Home)" : script.workingDirectory)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(script.workingDirectory.isEmpty ? .secondary : .primary)
                }
                
                DetailSection(title: "Options") {
                    HStack {
                        Image(systemName: script.isAutoStart ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(script.isAutoStart ? .green : .secondary)
                        Text("Auto-start when app launches")
                    }
                }
                
                if script.hasKillCommand {
                    DetailSection(title: "Force Kill Command") {
                        Text(script.killCommand)
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                            .textSelection(.enabled)
                    }
                }
                
                DetailSection(title: "Quick Actions") {
                    HStack(spacing: 12) {
                        if status == .running {
                            Button(action: onStop) {
                                Label("Stop", systemImage: "stop.fill")
                            }
                            .buttonStyle(.bordered)
                            .pointingHandCursor()
                            
                            Button(action: {
                                onStop()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    onStart()
                                }
                            }) {
                                Label("Restart", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .pointingHandCursor()
                        } else {
                            Button(action: onStart) {
                                Label("Start", systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .pointingHandCursor()
                        }
                        
                        Button(action: onViewLog) {
                            Label("View Logs", systemImage: "doc.text")
                        }
                        .buttonStyle(.bordered)
                        .pointingHandCursor()
                        
                        if script.hasKillCommand {
                            Button(role: .destructive) {
                                showForceKillConfirm = true
                            } label: {
                                Label("Force Kill", systemImage: "xmark.octagon.fill")
                            }
                            .buttonStyle(.bordered)
                            .help("Execute custom kill command to force stop the script")
                            .pointingHandCursor()
                        }
                    }
                }

            }
            .padding()
        }
        .alert("Force Kill Script?", isPresented: $showForceKillConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Force Kill", role: .destructive) {
                onForceKill()
            }
        } message: {
            Text("This will execute: \(script.killCommand)")
        }
    }
    
    private var editFormView: some View {
        Form {
            Section("Script Name") {
                TextField("Name", text: $editName)
                    .textFieldStyle(.roundedBorder)
            }
            
            Section("Command") {
                TextEditor(text: $editCommand)
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
                    TextField("Path (leave empty for home)", text: $editWorkingDirectory)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Browse...") {
                        selectDirectory()
                    }
                    .pointingHandCursor()
                }

            }
            
            Section("Options") {
                Toggle("Auto-start when app launches", isOn: $editIsAutoStart)
            }
            
            Section {
                TextEditor(text: $editKillCommand)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                Text("Optional: Commands to force kill when Stop doesn't work.\ne.g., pkill -f gkg && rm -f ~/.gkg/gkg.lock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                HStack {
                    Text("Force Kill Command")
                    Spacer()
                    if !editKillCommand.isEmpty {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private var footerView: some View {
        HStack {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .pointingHandCursor()
            
            Spacer()
            
            if isEditing {
                Button("Cancel") {
                    isEditing = false
                    resetEditFields()
                }
                .keyboardShortcut(.escape)
                .pointingHandCursor()
                
                Button("Save") {
                    saveChanges()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(editName.isEmpty || editCommand.isEmpty)
                .pointingHandCursor()
            } else {
                Button("Edit") {
                    isEditing = true
                }
                .buttonStyle(.borderedProminent)
                .pointingHandCursor()
            }
        }

        .padding()
        .alert("Delete Script?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This will stop the script and remove it permanently.")
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .stopped: return .gray
        case .running: return .green
        case .crashed: return .red
        }
    }
    
    private func resetEditFields() {
        editName = script.name
        editCommand = script.command
        editWorkingDirectory = script.workingDirectory
        editIsAutoStart = script.isAutoStart
        editKillCommand = script.killCommand
    }
    
    private func saveChanges() {
        var updated = script
        updated.name = editName
        updated.command = editCommand
        updated.workingDirectory = editWorkingDirectory
        updated.isAutoStart = editIsAutoStart
        updated.killCommand = editKillCommand
        onSave(updated)
        isEditing = false
    }
    
    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            editWorkingDirectory = url.path
        }
    }
}

struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            content
        }
    }
}

struct ScriptFormView: View {
    let mode: ScriptFormMode
    let onSave: (Script) -> Void
    let onCancel: () -> Void
    
    @State private var name: String = ""
    @State private var command: String = ""
    @State private var workingDirectory: String = ""
    @State private var isAutoStart: Bool = false
    @State private var killCommand: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Script")
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
                        .pointingHandCursor()
                    }
                }

                
                Section("Options") {
                    Toggle("Auto-start when app launches", isOn: $isAutoStart)
                }
                
                Section {
                    TextEditor(text: $killCommand)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    Text("Optional: Commands to force kill when Stop doesn't work.\ne.g., pkill -f gkg && rm -f ~/.gkg/gkg.lock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    HStack {
                        Text("Force Kill Command")
                        Spacer()
                        if !killCommand.isEmpty {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                .pointingHandCursor()
                
                Button("Create") {
                    let script = Script(
                        name: name,
                        command: command,
                        workingDirectory: workingDirectory,
                        isAutoStart: isAutoStart,
                        killCommand: killCommand
                    )
                    onSave(script)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || command.isEmpty)
                .pointingHandCursor()
            }

            .padding()
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
                    .pointingHandCursor()
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
            .pointingHandCursor()
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
                    .pointingHandCursor()
                    
                    Button("Restart") {
                        scriptManager.restartScript(script)
                    }
                    .pointingHandCursor()
                } else {
                    Button("Start") {
                        scriptManager.startScript(script)
                    }
                    .buttonStyle(.borderedProminent)
                    .pointingHandCursor()
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
                    .pointingHandCursor()
                    
                    Button("Import Configuration") {
                        importConfiguration()
                    }
                    .pointingHandCursor()
                }

                
                Text("Export your scripts to a JSON file for backup or sharing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("About") {
                LabeledContent("Version") {
                    Text("0.5.0")
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
                .pointingHandCursor()
        }
        .alert("Import Failed", isPresented: $showingImportError) {
            Button("OK", role: .cancel) {}
                .pointingHandCursor()
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
