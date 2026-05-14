import Sparkle
import SwiftUI

@MainActor
final class SparkleManager: NSObject, ObservableObject {
    private var updaterController: SPUStandardUpdaterController!
    @Published var canCheckForUpdates = false

    override init() {
        super.init()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}

extension SparkleManager: SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        "https://foldermind.app/appcast.xml"
    }
}
