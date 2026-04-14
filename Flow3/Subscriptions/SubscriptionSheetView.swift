import SwiftUI
import StoreKit

struct SubscriptionSheetView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "2A0C5A"),
                        Color(hex: "3B136E"),
                        Color(hex: "14062F")
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        headerCard
                        plansCard
                        restoreCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Flow Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

private extension SubscriptionSheetView {

    var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Upgrade your airport experience")
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(.white)

            Text("Get access to Flow Pro features, smarter planning, and premium airport tools.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.72))

            if subscriptionManager.isPro {
                Text("You’re currently on Flow Pro.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "9B6CFF"))
            }
        }
        .flowSettingsCard()
    }

    var plansCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Plans")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            if subscriptionManager.isLoadingProducts {
                ProgressView()
                    .tint(.white)
            } else {
                VStack(spacing: 12) {
                    subscriptionButton(
                        title: "Yearly",
                        subtitle: subscriptionManager.yearlyProduct?.displayPrice ?? "Loading...",
                        badge: "Best value",
                        action: {
                            Task {
                                _ = await subscriptionManager.purchaseYearly()
                            }
                        }
                    )

                    subscriptionButton(
                        title: "Monthly",
                        subtitle: subscriptionManager.monthlyProduct?.displayPrice ?? "Loading...",
                        badge: nil,
                        action: {
                            Task {
                                _ = await subscriptionManager.purchaseMonthly()
                            }
                        }
                    )
                }
            }

            if let error = subscriptionManager.lastErrorMessage, !error.isEmpty {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
            }
        }
        .flowSettingsCard()
    }

    var restoreCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                Task {
                    await subscriptionManager.restorePurchases()
                }
            } label: {
                HStack {
                    Text("Restore purchases")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .flowSettingsCard()
    }

    func subscriptionButton(
        title: String,
        subtitle: String,
        badge: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        if let badge {
                            Text(badge.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "9B6CFF"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.10))
                                )
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.68))
                }

                Spacer()

                if subscriptionManager.isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(subscriptionManager.isPurchasing)
    }
}


