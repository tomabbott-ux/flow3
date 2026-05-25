import SwiftUI
import StoreKit

struct PaywallView: View {

    enum PaywallSource: Equatable {
        case general
        case lockedAirport(code: String)
        case flightTracking
        case alerts

        var title: String {
            switch self {
            case .general:
                return "Try Flow Pro Free"
            case .lockedAirport(let code):
                return "Unlock \(code)"
            case .flightTracking:
                return "Try Flight Tracking Free"
            case .alerts:
                return "Try Smart Alerts Free"
            }
        }

        var subtitle: String {
            switch self {
            case .general:
                return "Start your 7-day free trial and unlock the full Flow airport experience."
            case .lockedAirport(let code):
                return "Start your 7-day free trial to unlock \(code) and every supported airport in Flow."
            case .flightTracking:
                return "Start your 7-day free trial to track flights, plan leave times, and stay ahead of changes."
            case .alerts:
                return "Start your 7-day free trial to unlock smarter alerts and premium travel notifications."
            }
        }
    }

    enum Plan {
        case yearly
        case monthly
    }

    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    let source: PaywallSource
    @Binding var isPresented: Bool

    @State private var selectedPlan: Plan = .yearly
    @State private var isRestoring = false

    private let termsURL = URL(string: "https://www.flowairport.com/terms-and-conditions")!
    private let privacyURL = URL(string: "https://www.flowairport.com/privacy-policy")!

    private var productsReady: Bool {
        subscriptionManager.yearlyProduct != nil && subscriptionManager.monthlyProduct != nil
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "090414"),
                    Color(hex: "14062F"),
                    Color(hex: "25104D"),
                    Color(hex: "12071E")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    topBar
                    hero
                    trialPill
                    benefitCard
                    planPicker
                    actionArea
                    legalFooter
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .task {
            if !subscriptionManager.hasLoadedProducts() {
                await subscriptionManager.loadProducts()
            }

            if subscriptionManager.isPro {
                dismissPaywall()
            }
        }
        .onChange(of: subscriptionManager.isPro) { _, isPro in
            if isPro {
                dismissPaywall()
            }
        }
        .alert(
            "Subscription Error",
            isPresented: Binding(
                get: { subscriptionManager.lastErrorMessage != nil },
                set: { newValue in
                    if !newValue {
                        subscriptionManager.clearLastError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                subscriptionManager.clearLastError()
            }
        } message: {
            Text(subscriptionManager.lastErrorMessage ?? "")
        }
    }
}

// MARK: - Sections

private extension PaywallView {

    var topBar: some View {
        HStack {
            Spacer()

            Button {
                dismissPaywall()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 34, height: 34)

                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .buttonStyle(.plain)
        }
    }

    var hero: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "9B6CFF").opacity(0.95),
                                Color(hex: "C45CFF").opacity(0.90)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)

                Image(systemName: "crown.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                Text(source.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(source.subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.74))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.top, 4)
    }

    var trialPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))

            Text("7 days free")
                .font(.system(size: 14, weight: .bold))

            Text("then choose monthly or yearly")
                .font(.system(size: 13, weight: .semibold))
                .opacity(0.82)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(hex: "9B6CFF").opacity(0.24))
                .overlay(
                    Capsule()
                        .stroke(Color(hex: "CBA8FF").opacity(0.26), lineWidth: 1)
                )
        )
    }

    var benefitCard: some View {
        VStack(spacing: 14) {
            benefitRow(
                icon: "globe",
                title: "All supported airports",
                subtitle: "Unlock every supported airport beyond the free selection."
            )

            benefitRow(
                icon: "airplane.departure",
                title: "Flight tracking",
                subtitle: "Track flights, gates, status changes, and smarter leave times."
            )

            benefitRow(
                icon: "bell.badge.fill",
                title: "Smart alerts",
                subtitle: "Get premium reminders when it is time to leave or your journey changes."
            )
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    func benefitRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "9B6CFF").opacity(0.18))
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: "CBA8FF"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    var planPicker: some View {
        VStack(spacing: 12) {
            planCard(
                plan: .yearly,
                title: "Yearly",
                subtitle: yearlySubtitle,
                badgeText: "Best Value",
                isSelected: selectedPlan == .yearly
            )

            planCard(
                plan: .monthly,
                title: "Monthly",
                subtitle: monthlySubtitle,
                badgeText: nil,
                isSelected: selectedPlan == .monthly
            )
        }
    }

    func planCard(
        plan: Plan,
        title: String,
        subtitle: String,
        badgeText: String?,
        isSelected: Bool
    ) -> some View {
        Button {
            selectedPlan = plan
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)

                        if let badgeText {
                            Text(badgeText)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "9B6CFF"))
                                )
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? Color(hex: "B98CFF") : Color.white.opacity(0.25),
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color(hex: "B98CFF"))
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                isSelected ? Color(hex: "A97DFF").opacity(0.8) : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    var actionArea: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await handlePurchaseTapped()
                }
            } label: {
                HStack {
                    Spacer()

                    if subscriptionManager.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else if subscriptionManager.isLoadingProducts {
                        Text("Loading plans…")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    } else {
                        Text(primaryButtonTitle)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Spacer()
                }
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [
                            Color(hex: "9B6CFF"),
                            Color(hex: "C45CFF")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .opacity(productsReady ? 1.0 : 0.72)
            }
            .buttonStyle(.plain)
            .disabled(subscriptionManager.isPurchasing || subscriptionManager.isLoadingProducts || !productsReady)

            Button {
                Task {
                    await handleRestoreTapped()
                }
            } label: {
                HStack {
                    if isRestoring {
                        ProgressView()
                            .tint(.white.opacity(0.85))
                    } else {
                        Text("Restore Purchases")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isRestoring || subscriptionManager.isPurchasing)

            if !productsReady && !subscriptionManager.isLoadingProducts {
                Text("Products not loaded yet. Check StoreKit setup or App Store Connect configuration.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }

    var legalFooter: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                Link("Terms of Use", destination: termsURL)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))

                Link("Privacy Policy", destination: privacyURL)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Text(legalBillingText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
                .multilineTextAlignment(.center)

            Text("Manage or cancel your subscription in your Apple Account settings. Restore Purchases is available above.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
    }

    var yearlySubtitle: String {
        if let product = subscriptionManager.yearlyProduct {
            return "7 days free, then \(product.displayPrice) / year"
        }
        return "7 days free, then yearly price"
    }

    var monthlySubtitle: String {
        if let product = subscriptionManager.monthlyProduct {
            return "7 days free, then \(product.displayPrice) / month"
        }
        return "7 days free, then monthly price"
    }

    var primaryButtonTitle: String {
        switch selectedPlan {
        case .yearly:
            return "Start 7-Day Free Trial"
        case .monthly:
            return "Start 7-Day Free Trial"
        }
    }

    var legalBillingText: String {
        switch selectedPlan {
        case .yearly:
            if let product = subscriptionManager.yearlyProduct {
                return "7-day free trial for eligible new subscribers. After the trial, payment will be charged to your Apple Account at \(product.displayPrice) per year unless cancelled at least 24 hours before the end of the trial or current period."
            }
            return "7-day free trial for eligible new subscribers. After the trial, payment will be charged to your Apple Account unless cancelled at least 24 hours before the end of the trial or current period."

        case .monthly:
            if let product = subscriptionManager.monthlyProduct {
                return "7-day free trial for eligible new subscribers. After the trial, payment will be charged to your Apple Account at \(product.displayPrice) per month unless cancelled at least 24 hours before the end of the trial or current period."
            }
            return "7-day free trial for eligible new subscribers. After the trial, payment will be charged to your Apple Account unless cancelled at least 24 hours before the end of the trial or current period."
        }
    }
}

// MARK: - Actions

private extension PaywallView {

    func handlePurchaseTapped() async {
        guard productsReady else {
            subscriptionManager.clearLastError()
            return
        }

        let success: Bool

        switch selectedPlan {
        case .yearly:
            success = await subscriptionManager.purchaseYearly()
        case .monthly:
            success = await subscriptionManager.purchaseMonthly()
        }

        if success {
            dismissPaywall()
        }
    }

    func handleRestoreTapped() async {
        isRestoring = true
        defer { isRestoring = false }

        await subscriptionManager.restorePurchases()

        if subscriptionManager.isPro {
            dismissPaywall()
        }
    }

    func dismissPaywall() {
        isPresented = false
        dismiss()
    }
}
