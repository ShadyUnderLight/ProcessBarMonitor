import SwiftUI

@main
struct ProcessBarMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel: MonitorViewModel

    init() {
        let vm = MonitorViewModel()
        _viewModel = StateObject(wrappedValue: vm)
        vm.start()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel)
        } label: {
            Text(viewModel.menuBarTitle)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)

        Settings {
            EmptyView()
        }
    }
}
