import Foundation

enum OnboardingStep: Int, CaseIterable {
    case welcome        = 0
    case folderPicker   = 1
    case starterRules   = 2
    case permissions    = 3
    case processing     = 4
    case done           = 5
}
