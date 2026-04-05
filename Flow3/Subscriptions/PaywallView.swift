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
                return "Upgrade to Flow Pro"
            case .lockedAirport(let code):
                return "Unlock \(code)"
            case .flightTracking:
                return "Unlock Flight Tracking"
            case .alerts:
                return "Unlock Smart Alerts"
            }
        }

        var subtitle: String {
            switch self {
            case .general:
                return "Get full airport access, flight tracking, and smarter travel tools."
            case .lockedAirport(let code):
                return "Get access to \(code) and every other premium airport in Flow."
            case .flightTracking:
                return "Track flights, plan leave times smarter, and stay ahead of changes."
            case .alerts:
                return "Get premium alerts and smarter notifications when it matters."
            }
        }
    }

    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    let source: PaywallSource
    @Binding var isPresented: Bool

    @State private var selectedPlan: Plan = .yearly
    @State private var isRestoring = false

    enum Plan {
        case yearly
        case monthly
    }

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
                    benefitCard
                    planPicker
                    actionArea
                    footer
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

    private var topBar: some View {
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

    private var hero: some View {
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
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(source.subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.top, 4)
    }

    private var benefitCard: some View {
        VStack(spacing: 14) {
            benefitRow(
                icon: "globe",
                title: "Full airport access",
                subtitle: "Unlock all airports beyond LAX, ORD, IST, AMS, and LGA."
            )

            benefitRow(
                icon: "airplane.departure",
                title: "Flight tracking",
                subtitle: "Track flights, plan leave times smarter, and stay ahead of changes."
            )

            benefitRow(
                icon: "bell.badge.fill",
                title: "Smarter alerts",
                subtitle: "Get more intelligent reminders and premium Flow notifications."
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

    private func benefitRow(icon: String, title: String, subtitle: String) -> some View {
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

    private var planPicker: some View {
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

    private func planCard(
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

    private var actionArea: some View {
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

    private var footer: some View {
        VStack(spacing: 10) {
            Text("Payment will be charged to your Apple Account at confirmation of purchase. Subscription renews automatically unless cancelled at least 24 hours before the end of the current period.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
                .multilineTextAlignment(.center)

            Text("Manage your subscription in your Apple Account settings.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
    }

    private var yearlySubtitle: String {
        if let product = subscriptionManager.yearlyProduct {
            return "\(product.displayPrice) / year"
        }
        return "Price unavailable"
    }

    private var monthlySubtitle: String {
        if let product = subscriptionManager.monthlyProduct {
            return "\(product.displayPrice) / month"
        }
        return "Price unavailable"
    }

    private var primaryButtonTitle: String {
        switch selectedPlan {
        case .yearly:
            if let product = subscriptionManager.yearlyProduct {
                return "Continue for \(product.displayPrice)"
            }
            return "Continue"
        case .monthly:
            if let product = subscriptionManager.monthlyProduct {
                return "Continue for \(product.displayPrice)"
            }
            return "Continue"
        }
    }

    private func handlePurchaseTapped() async {
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

    private func handleRestoreTapped() async {
        isRestoring = true
        defer { isRestoring = false }

        await subscriptionManager.restorePurchases()

        if subscriptionManager.isPro {
            dismissPaywall()
        }
    }

    private func dismissPaywall() {
        isPresented = false
        dismiss()
    }
}
