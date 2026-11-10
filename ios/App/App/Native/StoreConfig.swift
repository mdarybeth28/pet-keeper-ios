import Foundation

/// Everything about Pet Keeper's two payment doors, in one place.
///
/// Prices are SETTLED and do not change here: $3.99/month or
/// $29.99/year on every door (web Stripe, Apple IAP, Google later).
///
/// APPLE IAP DOOR: the product IDs below are named constants, not
/// App Store Connect facts yet. At Phase 3 (after the $99
/// enrollment) two auto-renewable subscription products must be
/// created in App Store Connect with EXACTLY these IDs, in one
/// subscription group, at $3.99 / $29.99:
///   - com.marybethsfinds.petkeeper.monthly
///   - com.marybethsfinds.petkeeper.yearly
/// Until those products exist, Product.products(for:) returns
/// nothing and the paywall says so honestly (see PaywallView).
///
/// WEB STRIPE DOOR (link-out): the same payment links the web app's
/// waiting room uses (PAY_MONTHLY_URL / PAY_YEARLY_URL in the v4.3
/// web app). US storefront rules currently allow this link-out
/// alongside IAP with no entitlement; the plan (§4) requires it to
/// sit behind ONE switchable flag so a future rule change is a
/// one-line switch, not a rebuild. The flag is a plain constant
/// today on purpose: flipping it ships in the next build, and no
/// server can silently change what a reviewed build does.
enum StoreConfig {
    // MARK: Apple IAP product IDs (create in App Store Connect, Phase 3)

    static let monthlyProductID = "com.marybethsfinds.petkeeper.monthly"
    static let yearlyProductID = "com.marybethsfinds.petkeeper.yearly"
    static let allProductIDs = [monthlyProductID, yearlyProductID]

    // MARK: US link-out door (switchable, plan §4)

    /// Set to false to remove the "Pay on our website" door from
    /// the paywall entirely. US storefront only while true.
    static let linkOutEnabledUS = true

    static let webMonthlyURL = URL(string: "https://buy.stripe.com/aFacN5dsG8uX5dz0xB0ZW03")!
    static let webYearlyURL = URL(string: "https://buy.stripe.com/9B68wP3S68uXaxTeor0ZW02")!

    // MARK: Owner accounts (mirrors the web app's OWNER_EMAILS)

    /// The web gate lets Mary's own emails in without an
    /// approved_emails row, checked in the page AND in the database
    /// helpers. The native gate mirrors the page half exactly.
    static let ownerEmails = [
        "marybeth.davis28@gmail.com",
        "affiliatefindstools@gmail.com",
    ]

    static func isOwner(email: String?) -> Bool {
        guard let email else { return false }
        return ownerEmails.contains(email.trimmingCharacters(in: .whitespaces).lowercased())
    }
}
