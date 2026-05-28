import SwiftUI
import AppKit

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
        .onReceive(NotificationCenter.default.publisher(for: .navigateToAction)) { notification in
            if let tab = notification.userInfo?["tab"] as? MainTab {
                selectedTab = tab
            }
            if let action = notification.userInfo?["action"] as? MainWindowAction {
                switch action {
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

private struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScriptsTabView: View {
    @EnvironmentObject var scriptManager: ScriptManager
    @Binding var isAddingScript: Bool
    @Binding var selectedScriptId: UUID?
    var onViewLog: (Script) -> Void
    @AppStorage("scripts.detailPanelWidth") private var detailPanelWidth: Double = 360

    private let minListWidth: CGFloat = 300
    private let minDetailWidth: CGFloat = 350
    
    private var selectedScript: Script? {
        guard let id = selectedScriptId else { return nil }
        return scriptManager.scripts.first { $0.id == id }
    }

    private var selectedScriptIndex: Int? {
        guard let id = selectedScriptId else { return nil }
        return scriptManager.scripts.firstIndex { $0.id == id }
    }
    
    var body: some View {
        HSplitView {
            scriptListView
                .frame(minWidth: minListWidth, maxWidth: .infinity)

            scriptDetailView
                .frame(minWidth: minDetailWidth, idealWidth: CGFloat(detailPanelWidth), maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
                .background {
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: WidthPreferenceKey.self, value: geometry.size.width)
                    }
                }
        }
        .onPreferenceChange(WidthPreferenceKey.self) { width in
            guard width >= minDetailWidth, abs(width - detailPanelWidth) > 0.5 else { return }
            detailPanelWidth = Double(width)
        }
        .onChange(of: selectedScriptId) { _, newValue in
            if newValue != nil {
                isAddingScript = false
            }
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
                        Button {
                            selectedScriptId = script.id
                            isAddingScript = false
                        } label: {
                            ScriptListRow(
                                script: script,
                                status: scriptManager.statuses[script.id] ?? .stopped,
                                isSelected: selectedScriptId == script.id,
                                onStart: { scriptManager.startScript(script) },
                                onStop: { scriptManager.stopScript(script) },
                                onViewLog: { onViewLog(script) }
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(selectedScriptId == script.id ? Color.accentColor.opacity(0.15) : Color.clear)
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
                scriptIndex: selectedScriptIndex,
                totalScripts: scriptManager.scripts.count,
                status: scriptManager.statuses[script.id] ?? .stopped,
                onSave: { updated in
                    scriptManager.updateScript(updated)
                },
                onDelete: {
                    scriptManager.deleteScript(script)
                    selectedScriptId = nil
                },
                onDuplicate: {
                    let duplicated = scriptManager.duplicateScript(script)
                    selectedScriptId = duplicated.id
                },
                onMoveUp: {
                    scriptManager.moveScript(id: script.id, by: -1)
                },
                onMoveDown: {
                    scriptManager.moveScript(id: script.id, by: 1)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        .foregroundColor(primaryTextColor)
                    
                    if script.isAutoStart {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundColor(isSelected ? .accentColor : .orange)
                    }
                }
                
                Text(script.command)
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
                    .lineLimit(1)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                if status == .running {
                    Button(action: onStop) {
                        Image(systemName: "stop.fill")
                            .font(.caption)
                            .foregroundColor(actionColor)
                    }
                    .buttonStyle(.borderless)
                    .help("Stop script")
                    .pointingHandCursor()
                } else {
                    Button(action: onStart) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundColor(actionColor)
                    }
                    .buttonStyle(.borderless)
                    .help("Start script")
                    .pointingHandCursor()
                }
                
                Button(action: onViewLog) {
                    Image(systemName: "doc.text")
                        .font(.caption)
                        .foregroundColor(actionColor)
                }
                .buttonStyle(.borderless)
                .help("View logs")
                .pointingHandCursor()
            }

        }
        .foregroundColor(primaryTextColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .pointingHandCursor()
    }
    
    private var statusColor: Color {
        if isSelected {
            return .accentColor
        }

        switch status {
        case .stopped: return .gray
        case .running: return .green
        case .crashed: return .red
        }
    }

    private var primaryTextColor: Color {
        isSelected ? .accentColor : .primary
    }

    private var secondaryTextColor: Color {
        isSelected ? .accentColor.opacity(0.85) : .secondary
    }

    private var actionColor: Color {
        isSelected ? .accentColor : .secondary
    }
}

enum ScriptFormMode {
    case add
    case edit(Script)
}

struct ScriptDetailView: View {
    let script: Script
    let scriptIndex: Int?
    let totalScripts: Int
    let status: ScriptStatus
    let onSave: (Script) -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
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
    @State private var copiedField: String?

    private var canMoveUp: Bool {
        guard let scriptIndex else { return false }
        return scriptIndex > 0
    }

    private var canMoveDown: Bool {
        guard let scriptIndex else { return false }
        return scriptIndex < totalScripts - 1
    }
    
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
                    HStack(alignment: .top, spacing: 8) {
                        Text(script.command)
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                            .textSelection(.enabled)
                        
                        CopyButton(text: script.command, fieldName: "command", copiedField: $copiedField)
                    }
                }
                
                DetailSection(title: "Working Directory") {
                    HStack(alignment: .top, spacing: 8) {
                        Text(script.workingDirectory.isEmpty ? "~ (Home)" : script.workingDirectory)
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                            .foregroundColor(script.workingDirectory.isEmpty ? .secondary : .primary)
                            .textSelection(.enabled)
                        
                        CopyButton(
                            text: script.workingDirectory.isEmpty ? "~" : script.workingDirectory,
                            fieldName: "workdir",
                            copiedField: $copiedField
                        )
                    }
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
                                scriptManager.restartScript(script)
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

                        Button(action: onDuplicate) {
                            Label("Duplicate", systemImage: "plus.square.on.square")
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

                DetailSection(title: "Position") {
                    HStack(spacing: 12) {
                        Button(action: onMoveUp) {
                            Label("Move Up", systemImage: "arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canMoveUp)
                        .pointingHandCursor()

                        Button(action: onMoveDown) {
                            Label("Move Down", systemImage: "arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canMoveDown)
                        .pointingHandCursor()
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
                FullWidthScriptNameField(placeholder: "Script Name", text: $editName)
            }
            
            Section("Command") {
                VStack(alignment: .leading, spacing: 8) {
                    AutoGrowingTextInput(placeholder: "Command", text: $editCommand)
                    Text("e.g., npm run dev, ./scripts/start.sh, gkg server start")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Directory") {
                WorkingDirectoryInputRow(text: $editWorkingDirectory, onBrowse: selectDirectory)
            }
            
            Section("Options") {
                Toggle("Auto-start when app launches", isOn: $editIsAutoStart)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    AutoGrowingTextInput(placeholder: "Force kill command", text: $editKillCommand)
                    Text("Optional: Commands to force kill when Stop doesn't work.\ne.g., pkill -f gkg && rm -f ~/.gkg/gkg.lock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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

struct CopyButton: View {
    let text: String
    let fieldName: String
    @Binding var copiedField: String?
    
    private var isCopied: Bool {
        copiedField == fieldName
    }
    
    var body: some View {
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copiedField = fieldName
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if copiedField == fieldName {
                    copiedField = nil
                }
            }
        }) {
            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 12))
                .foregroundColor(isCopied ? .green : .secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
        .help(isCopied ? "Copied!" : "Copy to clipboard")
        .pointingHandCursor()
        .animation(.easeInOut(duration: 0.15), value: isCopied)
    }
}

struct FullWidthScriptNameField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        AutoGrowingTextInput(placeholder: placeholder, text: $text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum InputFieldMetrics {
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 8
    static let cornerRadius: CGFloat = 10
    static let borderOpacity: Double = 0.2
    static let minimumHeight: CGFloat = 34
    static let textInset = NSSize(width: 0, height: 0)
    static let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    static let singleLineTextHeight: CGFloat = ceil(font.ascender - font.descender + font.leading)
}

struct AutoGrowingTextInput: View {
    let placeholder: String
    @Binding var text: String
    @State private var dynamicHeight: CGFloat = InputFieldMetrics.singleLineTextHeight

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, InputFieldMetrics.horizontalPadding)
                    .padding(.vertical, InputFieldMetrics.verticalPadding)
                    .allowsHitTesting(false)
            }

            AutoGrowingTextView(text: $text, measuredHeight: $dynamicHeight)
                .frame(height: max(InputFieldMetrics.singleLineTextHeight, dynamicHeight))
                .padding(.horizontal, InputFieldMetrics.horizontalPadding)
                .padding(.vertical, InputFieldMetrics.verticalPadding)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: InputFieldMetrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: InputFieldMetrics.cornerRadius)
                .stroke(Color.gray.opacity(InputFieldMetrics.borderOpacity), lineWidth: 1)
        )
        .frame(minHeight: max(InputFieldMetrics.minimumHeight, dynamicHeight + (InputFieldMetrics.verticalPadding * 2)))
    }
}

struct AutoGrowingTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var measuredHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, measuredHeight: $measuredHeight)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.allowsUndo = true
        textView.textContainerInset = InputFieldMetrics.textInset
        textView.font = InputFieldMetrics.font
        textView.textColor = NSColor.labelColor
        textView.alignment = .left
        textView.string = text

        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
            textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            textContainer.lineFragmentPadding = 0
            textContainer.lineBreakMode = .byCharWrapping
        }

        scrollView.documentView = textView

        DispatchQueue.main.async {
            context.coordinator.updateHeight(for: textView)
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        if textView.string != text {
            textView.string = text
        }

        textView.font = InputFieldMetrics.font
        textView.alignment = .left

        DispatchQueue.main.async {
            context.coordinator.updateHeight(for: textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        @Binding var measuredHeight: CGFloat

        init(text: Binding<String>, measuredHeight: Binding<CGFloat>) {
            _text = text
            _measuredHeight = measuredHeight
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            updateHeight(for: textView)
        }

        func updateHeight(for textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let newHeight = ceil(max(InputFieldMetrics.singleLineTextHeight, usedRect.height))

            if abs(measuredHeight - newHeight) > 0.5 {
                measuredHeight = newHeight
            }
        }
    }
}

struct WorkingDirectoryInputRow: View {
    @Binding var text: String
    let onBrowse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AutoGrowingTextInput(placeholder: "Path", text: $text)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Browse") {
                    onBrowse()
                }
                .pointingHandCursor()
            }

            Text("Path (leave empty for home)")
                .font(.caption)
                .foregroundColor(.secondary)
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
                    FullWidthScriptNameField(placeholder: "Script Name", text: $name)
                }
                
                Section("Command") {
                    VStack(alignment: .leading, spacing: 8) {
                        AutoGrowingTextInput(placeholder: "Command", text: $command)
                        Text("e.g., npm run dev, ./scripts/start.sh, gkg server start")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Directory") {
                    WorkingDirectoryInputRow(text: $workingDirectory, onBrowse: selectDirectory)
                }

                
                Section("Options") {
                    Toggle("Auto-start when app launches", isOn: $isAutoStart)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        AutoGrowingTextInput(placeholder: "Force kill command", text: $killCommand)
                        Text("Optional: Commands to force kill when Stop doesn't work.\ne.g., pkill -f gkg && rm -f ~/.gkg/gkg.lock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
    @State private var showClearConfirm = false

    private var logStore: LogStore? {
        guard let script = selectedScript else { return nil }
        return scriptManager.logs[script.id]
    }

    private var filteredEntryCount: Int {
        guard let store = logStore else { return 0 }
        if searchText.isEmpty {
            return store.count
        }
        return store.entries.filter { $0.message.localizedCaseInsensitiveContains(searchText) }.count
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
        .onChange(of: scriptManager.scripts) { _, newScripts in
            if let script = selectedScript,
               !newScripts.contains(where: { $0.id == script.id }) {
                selectedScript = nil
            }
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
                showClearConfirm = true
            }) {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(selectedScript == nil)
            .pointingHandCursor()
            .alert("Clear Logs", isPresented: $showClearConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    if let script = selectedScript {
                        scriptManager.clearLog(for: script)
                    }
                }
            } message: {
                Text("Are you sure you want to clear all logs for this script?")
            }
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
        if let script = selectedScript, let store = scriptManager.logs[script.id] {
            LogContentView(logStore: store, autoScroll: autoScroll, searchText: searchText)
        } else {
            emptyStateView
        }
    }
    
    private var footerView: some View {
        HStack {
            Text("\(filteredEntryCount) entries")
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

struct LogContentView: View {
    @ObservedObject var logStore: LogStore
    let autoScroll: Bool
    let searchText: String

    private var filteredEntries: [LogEntry] {
        if searchText.isEmpty {
            return logStore.entries
        }
        return logStore.entries.filter {
            $0.message.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        SelectableLogView(
            entries: filteredEntries,
            autoScroll: autoScroll,
            searchText: searchText
        )
    }
}

struct SettingsTabView: View {
    @EnvironmentObject var scriptManager: ScriptManager
    @State private var showingExportSuccess = false
    @State private var showingImportError = false
    @State private var importErrorMessage = ""

    private var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, buildVersion) {
        case let (short?, build?) where !short.isEmpty && !build.isEmpty:
            return "\(short) (\(build))"
        case let (short?, _):
            return short
        case let (_, build?):
            return build
        default:
            return "Unknown"
        }
    }
    
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
                    Text(appVersionText)
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

struct SelectableLogView: NSViewRepresentable {
    private static let timestampPattern = try! NSRegularExpression(pattern: #"^\[?\d{2}:\d{2}:\d{2}\]?\s*"#)

    let entries: [LogEntry]
    let autoScroll: Bool
    let searchText: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .noBorder
        
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        
        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        }
        
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView,
              let textStorage = textView.textStorage else { return }
        let coordinator = context.coordinator

        let searchTextChanged = searchText != coordinator.lastSearchText

        let needsFullRebuild = entries.count < coordinator.lastEntryCount ||
            coordinator.lastEntryCount == 0 ||
            (entries.isEmpty && coordinator.lastEntryCount > 0) ||
            (!entries.isEmpty && coordinator.firstEntryId != entries.first?.id) ||
            searchTextChanged

        if needsFullRebuild {
            textStorage.setAttributedString(buildAttributedString(from: entries))
            coordinator.lastEntryCount = entries.count
            coordinator.firstEntryId = entries.first?.id
            coordinator.lastSearchText = searchText
        } else if entries.count > coordinator.lastEntryCount {
            let newEntries = Array(entries[coordinator.lastEntryCount...])
            let appendStr = NSMutableAttributedString()
            if coordinator.lastEntryCount > 0 {
                appendStr.append(NSAttributedString(string: "\n"))
            }
            appendStr.append(buildAttributedString(from: Array(newEntries)))
            textStorage.append(appendStr)
            coordinator.lastEntryCount = entries.count
        }
        
        if autoScroll {
            textView.scrollToEndOfDocument(nil)
        }
    }
    
    private func buildAttributedString(from logEntries: [LogEntry]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let monoFont = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        
        // Paragraph style with tab stop for timestamp column alignment
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: 70)]
        paragraphStyle.defaultTabInterval = 70
        
        for (index, entry) in logEntries.enumerated() {
            let timestampAttrs: [NSAttributedString.Key: Any] = [
                .font: monoFont,
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle
            ]
            let messageAttrs: [NSAttributedString.Key: Any] = [
                .font: monoFont,
                .foregroundColor: entry.isError ? NSColor.systemRed : NSColor.labelColor
            ]
            
            // Add timestamp column
            result.append(NSAttributedString(string: entry.formattedTimestamp + "\t", attributes: timestampAttrs))
            
            // Strip duplicate [HH:MM:SS] prefix from message if present
            var messageText = entry.message
            let nsRange = NSRange(messageText.startIndex..., in: messageText)
            if let match = Self.timestampPattern.firstMatch(in: messageText, range: nsRange),
               let range = Range(match.range, in: messageText) {
                messageText = String(messageText[range.upperBound...])
            }
            result.append(NSAttributedString(string: messageText, attributes: messageAttrs))
            
            if index < logEntries.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }
        
        return result
    }
    
    final class Coordinator {
        var lastEntryCount: Int = 0
        var firstEntryId: UUID?
        var lastSearchText: String = ""
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
