import AppKit
import Combine
import IOKit.pwr_mgt
import ServiceManagement
import SwiftUI

@main
struct StayAwakeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var engine = AwakeEngine.shared

    var body: some Scene {
        MenuBarExtra {
            MenuRoot(engine: engine)
        } label: {
            Image(systemName: engine.isOn ? "cup.and.saucer.fill" : "cup.and.saucer")
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AwakeEngine.shared.restoreIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AwakeEngine.shared.stopAssertions()
    }
}

@MainActor
final class AwakeEngine: ObservableObject {
    static let shared = AwakeEngine()

    @Published var isOn: Bool = false
    @Published var durationMinutes: Int
    @Published var jiggleMinutes: Int
    @Published var startAtLogin: Bool
    @Published var startedAt: Date?

    private var displayAssertion: IOPMAssertionID = 0
    private var systemAssertion: IOPMAssertionID = 0
    private var ticker: Timer?
    private var lastJiggle: Date = .distantPast
    private let defaults = UserDefaults.standard

    private init() {
        durationMinutes = defaults.object(forKey: "durationMinutes") as? Int ?? 0
        jiggleMinutes = defaults.object(forKey: "jiggleMinutes") as? Int ?? 10
        startAtLogin = defaults.bool(forKey: "startAtLogin")
    }

    var elapsedLabel: String {
        guard isOn, let startedAt else { return "Off" }
        let s = Int(Date().timeIntervalSince(startedAt))
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 { return "Awake for \(h)h \(m)m" }
        if m > 0 { return "Awake for \(m) min" }
        return "Awake for \(s)s"
    }

    func restoreIfNeeded() {
        if defaults.bool(forKey: "isOn") {
            setOn(true)
        }
    }

    func toggle() {
        setOn(!isOn)
    }

    func setOn(_ on: Bool) {
        if on {
            start()
        } else {
            stop(persist: true)
        }
    }

    func setDuration(_ minutes: Int) {
        durationMinutes = minutes
        defaults.set(minutes, forKey: "durationMinutes")
    }

    func setJiggle(_ minutes: Int) {
        jiggleMinutes = minutes
        defaults.set(minutes, forKey: "jiggleMinutes")
        lastJiggle = Date()
    }

    func toggleLoginItem() {
        let next = !startAtLogin
        do {
            if next {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            startAtLogin = next
            defaults.set(next, forKey: "startAtLogin")
        } catch {
            let path = Bundle.main.bundlePath
            let script: String
            if next {
                script = "tell application \"System Events\" to make login item at end with properties {path:\"\(path)\", hidden:true, name:\"Stay Awake\"}"
            } else {
                script = "tell application \"System Events\" to delete (every login item whose name is \"Stay Awake\")"
            }
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            proc.arguments = ["-e", script]
            try? proc.run()
            startAtLogin = next
            defaults.set(next, forKey: "startAtLogin")
        }
    }

    private func start() {
        stopAssertions()
        createAssertion(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString, id: &displayAssertion)
        createAssertion(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString, id: &systemAssertion)
        isOn = true
        startedAt = Date()
        lastJiggle = Date()
        defaults.set(true, forKey: "isOn")
        startTicker()
    }

    func stop(persist: Bool) {
        stopAssertions()
        ticker?.invalidate()
        ticker = nil
        isOn = false
        startedAt = nil
        if persist {
            defaults.set(false, forKey: "isOn")
        }
    }

    func stopAssertions() {
        if displayAssertion != 0 {
            IOPMAssertionRelease(displayAssertion)
            displayAssertion = 0
        }
        if systemAssertion != 0 {
            IOPMAssertionRelease(systemAssertion)
            systemAssertion = 0
        }
    }

    private func createAssertion(_ type: CFString, id: inout IOPMAssertionID) {
        var assertion = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Stay Awake" as CFString,
            &assertion
        )
        if result == kIOReturnSuccess {
            id = assertion
        }
    }

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.onTick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func onTick() {
        guard isOn, let startedAt else { return }
        if durationMinutes > 0 {
            let elapsed = Date().timeIntervalSince(startedAt)
            if elapsed >= Double(durationMinutes) * 60 {
                stop(persist: true)
                return
            }
        }
        if jiggleMinutes > 0 {
            let due = Date().timeIntervalSince(lastJiggle)
            if due >= Double(jiggleMinutes) * 60 {
                jiggleCursor()
                lastJiggle = Date()
            }
        }
    }

    private func jiggleCursor() {
        let loc = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(loc) }) ?? NSScreen.main else {
            return
        }
        let point = CGPoint(x: loc.x, y: screen.frame.maxY - loc.y)
        let src = CGEventSource(stateID: .hidSystemState)
        if let move = CGEvent(
            mouseEventSource: src,
            mouseType: .mouseMoved,
            mouseCursorPosition: CGPoint(x: point.x + 1, y: point.y),
            mouseButton: .left
        ) {
            move.post(tap: .cghidEventTap)
        }
        if let moveBack = CGEvent(
            mouseEventSource: src,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) {
            moveBack.post(tap: .cghidEventTap)
        }
    }
}

struct MenuRoot: View {
    @ObservedObject var engine: AwakeEngine

    var body: some View {
        Button(engine.isOn ? "Turn Off" : "Turn On") {
            engine.toggle()
        }

        if engine.isOn {
            Text(engine.elapsedLabel)
        }

        Divider()

        Text("Keep Mac awake")
        durationButton("Until I turn it off", 0)
        durationButton("30 minutes", 30)
        durationButton("1 hour", 60)
        durationButton("3 hours", 180)
        durationButton("8 hours", 480)

        Divider()

        Text("Move cursor")
        jiggleButton("Off", 0)
        jiggleButton("Every 5 minutes", 5)
        jiggleButton("Every 10 minutes", 10)
        jiggleButton("Every 15 minutes", 15)

        Divider()

        Button(engine.startAtLogin ? "Start at login ✓" : "Start at login") {
            engine.toggleLoginItem()
        }

        Divider()

        Button("Quit Stay Awake") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func durationButton(_ title: String, _ minutes: Int) -> some View {
        Button((engine.durationMinutes == minutes ? "✓  " : "    ") + title) {
            engine.setDuration(minutes)
        }
    }

    private func jiggleButton(_ title: String, _ minutes: Int) -> some View {
        Button((engine.jiggleMinutes == minutes ? "✓  " : "    ") + title) {
            engine.setJiggle(minutes)
        }
    }
}
