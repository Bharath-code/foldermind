import Foundation

struct LicenseManager {
    static let shared = LicenseManager()

    private let userDefaults = UserDefaults.standard
    private let licenseKeyKey = "foldermind_license_key"
    private let licensedAtKey = "foldermind_licensed_at"
    private let firstLaunchDateKey = "foldermind_first_launch_date"
    
    private let trialDurationDays = 7

    var isLicensed: Bool {
        userDefaults.string(forKey: licenseKeyKey) != nil
    }
    
    var firstLaunchDate: Date {
        if let date = userDefaults.object(forKey: firstLaunchDateKey) as? Date {
            return date
        }
        let now = Date()
        userDefaults.set(now, forKey: firstLaunchDateKey)
        return now
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let expiryDate = calendar.date(byAdding: .day, value: trialDurationDays, to: firstLaunchDate)!
        
        // Use startOfDay to be fair to the user
        let startOfNow = calendar.startOfDay(for: Date())
        let startOfExpiry = calendar.startOfDay(for: expiryDate)
        
        let components = calendar.dateComponents([.day], from: startOfNow, to: startOfExpiry)
        return max(0, components.day ?? 0)
    }
    
    var isTrialExpired: Bool {
        if isLicensed { return false }
        return daysRemaining <= 0 && Date() > Calendar.current.date(byAdding: .day, value: trialDurationDays, to: firstLaunchDate)!
    }

    func validate(key: String) -> Bool {
        // Simple mock validation: 24 chars, must have dashes
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

    // MARK: - Debug Helpers
    
    func resetTrial() {
        userDefaults.removeObject(forKey: firstLaunchDateKey)
        revoke()
    }
    
    func simulateExpiry() {
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        userDefaults.set(eightDaysAgo, forKey: firstLaunchDateKey)
    }
}
