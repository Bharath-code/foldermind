import Foundation
import CryptoKit

struct LicenseManager {
    static let shared = LicenseManager()

    private let keychain = KeychainManager.shared
    private let userDefaults = UserDefaults.standard
    private let licenseKeyKey = "foldermind_license_key"
    private let licensedAtKey = "foldermind_licensed_at"
    private let firstLaunchDateKey = "foldermind_first_launch_date"

    private let trialDurationDays = 7

    private let hmacKey: SymmetricKey = {
        let seed: [UInt8] = [
            0x4F, 0x6C, 0x64, 0x4D, 0x69, 0x6E, 0x64, 0x4B,
            0x65, 0x79, 0x46, 0x6F, 0x6C, 0x64, 0x65, 0x72,
            0x53, 0x65, 0x63, 0x72, 0x65, 0x74, 0x32, 0x35,
            0x36, 0x4B, 0x65, 0x79, 0x53, 0x65, 0x65, 0x64
        ]
        return SymmetricKey(data: Data(seed))
    }()

    var isLicensed: Bool {
        keychain.get(key: licenseKeyKey) != nil
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
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard trimmed.hasPrefix("FMLM-") else { return false }
        guard trimmed.count == 19 else { return false }

        let keyBody = String(trimmed.dropFirst(5))
        let parts = keyBody.split(separator: "-")
        guard parts.count == 3 else { return false }

        let payload = parts[0] + parts[1]
        guard payload.count == 8, payload.allSatisfy({ $0.isHexDigit }) else { return false }

        let providedSignature = String(parts[2])
        guard providedSignature.count == 4 else { return false }

        let message = "FMLM-" + payload
        guard let messageData = message.data(using: .utf8) else { return false }

        let hmac = HMAC<SHA256>.authenticationCode(for: messageData, using: hmacKey)
        let expectedSignature = String(Data(hmac).prefix(2).map { String(format: "%02X", $0) }.joined())

        guard providedSignature == expectedSignature else { return false }

        guard keychain.save(key: licenseKeyKey, value: trimmed) else { return false }
        userDefaults.set(Date(), forKey: licensedAtKey)
        return true
    }

    func revoke() {
        keychain.delete(key: licenseKeyKey)
        userDefaults.removeObject(forKey: licensedAtKey)
    }

#if DEBUG
    func resetTrial() {
        userDefaults.removeObject(forKey: firstLaunchDateKey)
        revoke()
    }

    func simulateExpiry() {
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        userDefaults.set(eightDaysAgo, forKey: firstLaunchDateKey)
    }
#endif
}
