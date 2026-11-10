import SwiftUI

/// The native waiting room — shown when a signed-in account is not
/// approved yet, the native twin of the web app's waiting room.
///
/// It offers BOTH payment doors side by side, neither hidden:
///   1. Apple IAP (required to exist; the primary in-app door).
///   2. The web Stripe link-out, behind StoreConfig.linkOutEnabledUS
///      (US storefront rule; one-line switch, per plan §4).
/// Wording follows the web waiting room's honesty: use the SAME
/// email at checkout, paying lets you in by itself, and access is
/// confirmed by the backend — after an Apple purchase this screen
/// sits in a plain "finishing setup" state while ApprovalStore
/// polls, and if the row has not landed yet it says so and offers
/// Check again instead of pretending.
struct PaywallView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var approval: ApprovalStore
    @EnvironmentObject private var subscriptions: SubscriptionStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let email = session.currentEmail {
                    Text("Signed in as \(email)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                statusSection
                appleDoor
                if StoreConfig.linkOutEnabledUS { webDoor }
                restoreRow
                signOutRow
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            subscriptions.start()
            if approval.state == .unknown {
                await approval.check(session: session)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🐾 Almost in")
                .font(.title2).fontWeight(.bold)
            Text("Pet Keeper is $3.99 a month or $29.99 a year — upkeep included, nothing sold as extras. Join below and Pet Keeper lets you in automatically, as soon as your payment finishes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        switch subscriptions.phase {
        case .finishingSetup:
            Label("Payment finished — we're confirming it now. This can take a few seconds…", systemImage: "hourglass")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                checkAgainButton
            }
        default:
            if approval.state == .waiting {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If you've already paid — on the website or in the app — your confirmation may still be on its way.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    checkAgainButton
                }
            }
        }
    }

    private var checkAgainButton: some View {
        Button("Check again") {
            Task { await approval.check(session: session) }
        }
        .disabled(approval.state == .checking)
    }

    private var appleDoor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Subscribe in the app")
                .font(.headline)
            if subscriptions.products.isEmpty {
                Text(subscriptions.phase == .loadingProducts
                     ? "Loading the subscription options…"
                     : "The subscription options could not be loaded from Apple right now. Check your connection, or use the website door below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if subscriptions.phase != .loadingProducts {
                    Button("Try loading again") {
                        Task { await subscriptions.loadProducts() }
                    }
                }
            } else {
                ForEach(subscriptions.products, id: \.id) { product in
                    Button {
                        Task {
                            await subscriptions.purchase(productID: product.id, session: session) {
                                _ = await approval.checkUntilApproved(session: session)
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.displayName).fontWeight(.semibold)
                                Text(product.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if subscriptions.phase == .purchasing(productID: product.id) {
                                ProgressView()
                            } else {
                                Text(product.displayPrice).fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(subscriptions.isBusy)
                }
            }
            if subscriptions.hasAppleEntitlement {
                Text("This Apple account already has an active Pet Keeper subscription. If the app has not opened yet, tap \"Check again\" above — your confirmation may still be landing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var webDoor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Text("Or pay on our website")
                .font(.headline)
            Text("Same prices, same account. Use this same email at checkout — then come back here and tap \"Check again.\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Pay monthly on our website — $3.99") {
                openURL(StoreConfig.webMonthlyURL)
            }
            Button("Pay yearly on our website — $29.99") {
                openURL(StoreConfig.webYearlyURL)
            }
        }
    }

    private var restoreRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Button("Restore purchases") {
                Task {
                    await subscriptions.restore()
                    _ = await approval.checkUntilApproved(session: session, attempts: 3, delaySeconds: 3)
                }
            }
            .disabled(subscriptions.isBusy)
            Text("Bought Pet Keeper in the app before — on this phone or another one? Restore brings the purchase back, then we check your account again.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var signOutRow: some View {
        Button("Sign out", role: .destructive) {
            Task {
                await session.signOut()
                approval.reset()
            }
        }
        .font(.subheadline)
    }
}
