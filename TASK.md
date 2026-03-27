Build a native macOS menu bar app in Swift/SwiftUI named ProcessBarMonitor.

Requirements:
- Menu bar extra app (menu bar utility, no regular main window required).
- Show current overall CPU %, memory used/total, and thermal state in the menu bar title if concise enough.
- In the menu content, show:
  - Summary cards for CPU, memory, thermal state.
  - Top processes by CPU (at least top 8)
  - Top processes by memory (at least top 8)
  - Each process row should include process name, pid, cpu percent, memory MB.
  - Manual refresh button and auto-refresh every ~2 seconds.
- Use native APIs when practical. For process data, shelling out to ps/top is acceptable for MVP if wrapped cleanly.
- For CPU temperature: implement a best-effort provider. If real CPU temperature is unavailable through safe/public APIs, display thermal state text instead and architecture note. Do not require sudo. No private entitlements.
- Should compile on modern macOS with SwiftUI.
- Create a full Xcode project structure manually if needed (Package.swift is not enough by itself for a menu bar app; create source files and an .xcodeproj if feasible, but a well-structured Swift package/macOS app target is acceptable if buildable with swift build is impossible for MenuBarExtra. Prefer an Xcode project if practical.)
- Include README.md with run/build notes and known limitations.
- Keep code reasonably clean and split into files.

Deliverables in the current directory.

When completely finished, run this command to notify me:
openclaw system event --text "Done: Built ProcessBarMonitor native macOS menu bar app MVP in /tmp/process-bar-monitor" --mode now
