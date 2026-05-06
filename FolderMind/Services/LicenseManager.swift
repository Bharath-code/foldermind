import Foundation

struct LicenseManager {
    static let shared = LicenseManager()

    private let userDefaults = UserDefaults.standard
    private let licenseKeyKey = "foldermind_license_key"
    private let licensedAtKey = "foldermind_licensed_at"

    var isLicensed: Bool {
        userDefaults.string(forKey: licenseKeyKey) != nil
    }

    func validate(key: String) -> Bool {
        guard key.count == 24 else { return false }
        guard key.contains("-") else { return false }

        userDefaults.set(key, forKey: licenseKeyKey)
        userDefaults.set(Date(), forKey: licensedAtKey)
        return true
    }

    func revoke() {
        userDefaults.removeObject(forKey: licenseKeyKey)
        userDefaults.removeObject(forKey: licensedAtKey)
    }
}
