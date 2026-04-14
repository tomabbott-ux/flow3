import SwiftUI
import UIKit
import StoreKit

struct SettingsView: View {

    @EnvironmentObject private var store: LandingStore
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    @AppStorage("flow_default_airport") private var defaultAirportRawValue: String = FlowAirport.atl.rawValue
    @AppStorage("flow_use_24h_time") private var use24HourTime: Bool = true
    @AppStorage("flow_use_celsius") private var useCelsius: Bool = true
    @AppStorage("flow_auto_select_fastest_checkpoint") private var autoSelectFastestCheckpoint: Bool = true
    @AppStorage("flow_prefer_precheck") private var preferPreCheck: Bool = false
    @AppStorage("flow_calendar_flight_detection_enabled") private var calendarFlightDetectionEnabled: Bool = true
    @AppStorage("flow_airport_sort_mode") private var airportSortMode: String = "code"

    @AppStorage("flow_notify_30") private var notify30Minutes: Bool = true
    @AppStorage("flow_notify_15") private var notify15Minutes: Bool = true
    @AppStorage("flow_notify_leave_now") private var notifyLeaveNow: Bool = true
    @AppStorage("flow_notify_gate") private var notifyGateTarget: Bool = true

    @StateObject private var flightUsageTracker = FlightAPIUsageTracker.shared
    @State private var showSubscriptionSheet = false
    @State private var showFeedbackUnavailableAlert = false

    private let supportedAirports: [FlowAirport] = AirportRegistry.airports.map(\.airport)

    var body: some View {
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
                    headerSection
                    displayCard
                    planningCard
                    notificationsCard
                    subscriptionCard
                    aboutCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            SubscriptionSheetView()
        }
        .alert("Mail Not Available", isPresented: $showFeedbackUnavailableAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Mail is not available on this device. Please email admin@flowairport.com manually.")
        }
    }
}

// MARK: - Header

private extension SettingsView {

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(.white)

            Text("Preferences and app controls for your Flow experience.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
        }
    }
}

// MARK: - Display

private extension SettingsView {

    var displayCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Display")

            VStack(alignment: .leading, spacing: 8) {
                settingLabel("Default airport")

                Picker("", selection: $defaultAirportRawValue) {
                    ForEach(supportedAirports, id: \.rawValue) { airport in
                        Text("\(airport.rawValue) · \(airport.displayName)")
                            .tag(airport.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                settingLabel("Time format")

                Picker("", selection: $use24HourTime) {
                    Text("24-hour").tag(true)
                    Text("12-hour").tag(false)
                }
                .pickerStyle(.segmented)
                .flowSegmentedStyle()
            }

            VStack(alignment: .leading, spacing: 8) {
                settingLabel("Temperature")

                Picker("", selection: $useCelsius) {
                    Text("°C").tag(true)
                    Text("°F").tag(false)
                }
                .pickerStyle(.segmented)
                .flowSegmentedStyle()
            }

            VStack(alignment: .leading, spacing: 8) {
                settingLabel("Airport sorting")

                Picker("", selection: $airportSortMode) {
                    Text("Airport code").tag("code")
                    Text("Airport name").tag("name")
                }
                .pickerStyle(.segmented)
                .flowSegmentedStyle()
            }
        }
        .flowSettingsCard()
    }
}

// MARK: - Planning

private extension SettingsView {

    var planningCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Planning")

            Toggle(isOn: $autoSelectFastestCheckpoint) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Auto-select fastest checkpoint")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Flow picks the quickest available checkpoint automatically.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.68))
                }
            }
            .tint(Color(hex: "9B6CFF"))

            Toggle(isOn: $preferPreCheck) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Prefer PreCheck")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Prefer PreCheck routes where available.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.68))
                }
            }
            .tint(Color(hex: "9B6CFF"))
            .onChange(of: preferPreCheck) { _, _ in
                store.refreshTrackedFlightSecurityIfNeeded()
            }

            Toggle(isOn: $calendarFlightDetectionEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Calendar flight detection")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Let Flow detect upcoming flights in Calendar and offer to track them.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.68))
                }
            }
            .tint(Color(hex: "9B6CFF"))
        }
        .flowSettingsCard()
    }
}

// MARK: - Notifications

private extension SettingsView {

    var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Notifications")

            Toggle("Leave in 30 minutes", isOn: $notify30Minutes)
                .flowSettingsToggleStyle()

            Toggle("Leave in 15 minutes", isOn: $notify15Minutes)
                .flowSettingsToggleStyle()

            Toggle("Leave now", isOn: $notifyLeaveNow)
                .flowSettingsToggleStyle()

            Toggle("Gate target reminder", isOn: $notifyGateTarget)
                .flowSettingsToggleStyle()
        }
        .flowSettingsCard()
    }
}

// MARK: - Subscription

private extension SettingsView {

    var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Subscription")

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current plan")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.68))

                    Text(currentPlanTitle)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                Text(currentPlanTitle.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "9B6CFF"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
            }

            Button {
                showSubscriptionSheet = true
            } label: {
                HStack {
                    Text(subscriptionManager.isPro ? "Manage subscription" : "View plans")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "chevron.right")
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

    var currentPlanTitle: String {
        subscriptionManager.isPro ? "Pro" : "Free"
    }
}

// MARK: - About

private extension SettingsView {

    var aboutCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("About")

            infoRow(title: "App version", value: appVersionString)
            infoRow(title: "Build", value: buildNumberString)
            infoRow(title: "Theme", value: "Flow")

            Text("Flow helps you decide when to leave for the airport using live wait times, travel time, and smart planning.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .background(Color.white.opacity(0.2))

            Button {
                sendFeedback()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "CBA8FF"))

                    Text("Send Feedback")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            Button {
                requestAppReview()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "FFD166"))

                    Text("Rate Flow")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .flowSettingsCard()
    }

    func sendFeedback() {
        let email = "admin@flowairport.com"
        let subject = "Flow Feedback"

        let body = """
Hi Flow Team,

---

App Version: \(appVersionString)
Build: \(buildNumberString)
Device: \(UIDevice.current.model)
iOS: \(UIDevice.current.systemVersion)
Default Airport: \(defaultAirportRawValue)
Subscription: \(currentPlanTitle)
"""

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        guard let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") else {
            showFeedbackUnavailableAlert = true
            return
        }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            showFeedbackUnavailableAlert = true
        }
    }

    func requestAppReview() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    var appVersionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumberString: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Helpers

private extension SettingsView {

    func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
    }

    func settingLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white.opacity(0.68))
    }

    func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.72))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Styling

extension View {

    func flowSettingsCard() -> some View {
        self
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 10)
    }

    func flowSettingsToggleStyle() -> some View {
        self
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .tint(Color(hex: "9B6CFF"))
    }

    func flowSegmentedStyle() -> some View {
        self
            .colorScheme(.dark)
            .tint(Color(hex: "9B6CFF"))
    }
}
