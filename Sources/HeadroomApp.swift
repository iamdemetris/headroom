import SwiftUI

@main
struct HeadroomApp: App {
    @State private var fleet = FleetModel()

    var body: some Scene {
        MenuBarExtra {
            MenuRoot(fleet: fleet)
        } label: {
            MenuLabel(fleet: fleet)
                .task { fleet.start() }
        }
        .menuBarExtraStyle(.window)
    }
}
