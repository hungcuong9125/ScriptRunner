# ScriptRunner

A simple macOS Menu Bar application to manage and run scripts in the background.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5](https://img.shields.io/badge/Swift-5-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-blue)

## Features

- 🖥️ **Menu Bar App** - Lives in your menu bar, always accessible
- ▶️ **Run Scripts** - Execute shell commands in the background
- 📊 **Status Indicators** - See running/stopped/crashed status at a glance
- 📜 **Real-time Logs** - View stdout/stderr with search and auto-scroll
- ⚡ **Auto-start** - Automatically run selected scripts when app launches
- 🔔 **Notifications** - Get notified when scripts crash
- 💾 **Export/Import** - Backup and share your script configurations
- ⌨️ **Keyboard Shortcuts** - Quick access to common actions

## Installation

### Build from Source

1. Open `ScriptRunner.xcodeproj` in Xcode 15+
2. Select your development team in Signing & Capabilities
3. Build and run (⌘R)
4. Optionally, archive and export for distribution

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ for building

## Usage

### Adding a Script

1. Click the terminal icon in the menu bar
2. Click "Add" button
3. Fill in:
   - **Name**: A friendly name for your script
   - **Command**: The shell command to execute (e.g., `npm run dev`)
   - **Working Directory**: Where to run the command (optional)
   - **Auto-start**: Enable to run automatically on app launch

### Managing Scripts

- **Start/Stop**: Click the play/stop buttons on each script
- **Restart**: Available for running scripts
- **View Log**: Click the document icon to see output
- **Edit/Delete**: Right-click on a script for more options

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘N | Add new script |
| ⌘⇧R | Start all scripts |
| ⌘. | Stop all scripts |
| ⌘Q | Quit application |

## Example Scripts

### MCP Servers

```
Name: GKG Server
Command: gkg server start
Working Directory: (leave empty)
Auto-start: ✓
```

```
Name: Mail Agent MCP
Command: scripts/run_server_with_token.sh
Working Directory: /Users/yourname/Developer/TOOLS/mcp_agent_mail
Auto-start: ✓
```

### Development Servers

```
Name: Frontend Dev
Command: npm run dev
Working Directory: /path/to/your/frontend
```

```
Name: Backend API
Command: python manage.py runserver
Working Directory: /path/to/your/backend
```

## Configuration

Scripts are stored in UserDefaults and persist between sessions.

### Export/Import

1. Open Settings (right-click menu bar icon > Settings)
2. Go to "Data" tab
3. Use Export to save to JSON file
4. Use Import to restore from JSON file

## Architecture

```
ScriptRunner/
├── ScriptRunnerApp.swift     # App entry point
├── AppDelegate.swift         # Lifecycle & notifications
├── Models/
│   ├── Script.swift          # Script data model
│   └── LogEntry.swift        # Log entry model
├── ViewModels/
│   └── ScriptManager.swift   # Core business logic
└── Views/
    ├── MenuBarView.swift     # Main menu bar UI
    ├── ScriptEditorView.swift # Add/Edit dialog
    ├── LogViewerView.swift   # Log viewer window
    └── SettingsView.swift    # Settings window
```

## Future Improvements

Here are planned features for future versions:

### High Priority
- [ ] **Script Groups** - Organize scripts by project/category
- [ ] **Launch at Login** - Option to start app automatically on macOS login
- [ ] **Script Dependencies** - Start scripts in order with dependencies

### Medium Priority
- [ ] **Environment Variables** - Custom env vars per script
- [ ] **Script Templates** - Pre-defined templates for common setups
- [ ] **Health Checks** - Periodic checks to verify scripts are responding
- [ ] **Auto-restart** - Automatically restart crashed scripts

### Nice to Have
- [ ] **Custom Icons** - Per-script icons in menu
- [ ] **Statistics** - Track uptime, restart count, etc.
- [ ] **Remote Scripts** - SSH to remote servers
- [ ] **Scheduled Execution** - Cron-like scheduling
- [ ] **Multi-window Logs** - Open multiple log windows simultaneously

## Troubleshooting

### Script won't start
- Check the working directory path exists
- Verify the command works in Terminal
- Check logs for error messages

### Logs not showing
- Ensure the script outputs to stdout/stderr
- Some scripts buffer output - try adding flush statements

### Notifications not working
- Grant notification permission in System Settings > Notifications

## License

MIT License - feel free to use and modify.

## Contributing

Contributions are welcome! Please open an issue or pull request.
