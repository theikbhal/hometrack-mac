import SwiftUI
import Charts
import AppKit

// MARK: - Reports
struct ReportsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var tracker: TimeTracker

    private func color(_ score: Int?) -> Color {
        guard let sc = score else { return Color.gray.opacity(0.2) }
        if sc >= 100 { return Color.green }
        if sc >= store.s.passMark { return Color.teal }
        return Color.orange
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    PageTitle(text: "Reports")
                    Spacer()
                    CopyButton(title: "Copy report", text: store.reportText())
                    CopyButton(title: "Copy CSV", text: store.csv())
                }
                HStack(spacing: 12) {
                    StatTile(icon: "fuelpump.fill", title: "Petrol (month)", value: rs(store.monthTotal(.petrol)), tint: .orange)
                    StatTile(icon: "takeoutbag.and.cup.and.straw.fill", title: "Snacks (month)", value: rs(store.monthTotal(.snacks)), tint: .purple)
                    StatTile(icon: "drop.fill", title: "Water (month)", value: rs(store.monthTotal(.water)), tint: .blue)
                    StatTile(icon: "sum", title: "Total (month)", value: rs(store.monthGrand), tint: .teal)
                }
                VStack(alignment: .leading) {
                    Text("Spending by month").font(.headline)
                    Chart(store.monthlyStats(6)) { m in
                        BarMark(x: .value("Month", m.month, unit: .month), y: .value("Rupees", m.amount))
                            .foregroundStyle(by: .value("Category", m.cat))
                    }
                    .frame(height: 240)
                }
                .card()
                HStack(spacing: 12) {
                    StatTile(icon: "flame.fill", title: "Pass streak", value: "\(store.streak)", tint: .orange)
                    StatTile(icon: "checkmark.seal.fill", title: "Days passed (28d)",
                             value: "\(store.lastDays(28).filter { (store.scores[dayKey($0)] ?? 0) >= store.s.passMark }.count)", tint: .green)
                    StatTile(icon: "speedometer", title: "Mileage", value: store.mileage.map { String(format: "%.1f km/l", $0.kmPerL) } ?? "-", tint: .teal)
                    StatTile(icon: "infinity", title: "Time in app", value: fmtLong(tracker.total), tint: .purple)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Daily score, last 28 days (pass mark \(store.s.passMark))").font(.headline)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                        ForEach(store.lastDays(28), id: \.self) { d in
                            Text("\(Calendar.current.component(.day, from: d))")
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .background(color(store.scores[dayKey(d)]), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    Text("Green = perfect 100, teal = pass, orange = below pass mark, grey = no data")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .card()
            }
            .padding(24)
        }
    }
}

// MARK: - Calculator
struct CalcView: View {
    @State private var dist = "100"
    @State private var mileage = "40"
    @State private var price = "105"
    @State private var amt = "500"
    @State private var price2 = "105"
    @State private var cans = "10"
    @State private var canPrice = "40"
    @State private var people = "4"
    @State private var perDay = "20"
    @State private var bill = "1200"
    @State private var split = "4"

    private func d(_ s: String) -> Double { Double(s) ?? 0 }
    private func div(_ a: Double, _ b: Double) -> Double { b == 0 ? 0 : a / b }

    private func field(_ title: String, _ text: Binding<String>) -> some View {
        HStack {
            Text(title).frame(width: 190, alignment: .leading)
            TextField("", text: text).textFieldStyle(.roundedBorder).frame(width: 120)
        }
    }

    private func result(_ title: String, _ text: String) -> some View {
        HStack {
            Text(text).font(.headline)
            Spacer()
            CopyButton(title: "Copy", text: "\(title): \(text)")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageTitle(text: "Calculator")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Trip fuel cost").font(.headline)
                    field("Distance (km)", $dist); field("Mileage (km/l)", $mileage); field("Petrol price (₹/l)", $price)
                    let l = div(d(dist), d(mileage))
                    result("Trip fuel", String(format: "%.2f L, ", l) + rs(l * d(price)))
                }.card()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Fill by amount").font(.headline)
                    field("Amount (₹)", $amt); field("Petrol price (₹/l)", $price2)
                    result("Fill", String(format: "%.2f litres", div(d(amt), d(price2))))
                }.card()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Water cost").font(.headline)
                    field("Cans per month", $cans); field("Price per can (₹)", $canPrice)
                    let m = d(cans) * d(canPrice)
                    result("Water", "\(rs(m)) per month, \(rs(m * 12)) per year")
                }.card()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Family snack budget").font(.headline)
                    field("People", $people); field("Per person per day (₹)", $perDay)
                    let m = d(people) * d(perDay) * 30
                    result("Snack budget", "\(rs(m)) per month")
                }.card()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Split a bill").font(.headline)
                    field("Total (₹)", $bill); field("Split between", $split)
                    result("Split", "\(rs(div(d(bill), d(split)), 2)) each")
                }.card()
            }
            .padding(24)
        }
    }
}

// MARK: - Your own pages
struct PagesView: View {
    @EnvironmentObject var store: Store
    @State private var sel: UUID?
    private var idx: Int? { store.s.notes.firstIndex { $0.id == sel } }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("My Pages").font(.title2.bold())
                List(selection: $sel) {
                    ForEach(store.s.notes) { n in Text(n.title).tag(n.id as UUID?) }
                }
                .frame(width: 210)
                HStack {
                    Button("New page") {
                        let n = NotePage(title: "Page \(store.s.notes.count + 1)", body: "")
                        store.s.notes.append(n); sel = n.id
                    }
                    Button("Delete") {
                        if let i = idx, store.s.notes.count > 1 { store.s.notes.remove(at: i); sel = store.s.notes.first?.id }
                    }
                }
            }
            .padding(.leading, 24).padding(.vertical, 24)

            if let i = idx {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Title", text: $store.s.notes[i].title)
                        .textFieldStyle(.roundedBorder).font(.title3)
                    TextEditor(text: $store.s.notes[i].body)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    CopyButton(title: "Copy page", text: store.s.notes[i].body)
                }
                .padding(.trailing, 24).padding(.vertical, 24)
            } else {
                Text("Select or create a page.").foregroundStyle(.secondary).padding(40)
            }
        }
        .onAppear { if sel == nil { sel = store.s.notes.first?.id } }
    }
}

// MARK: - Help (static pages)
struct HelpSection: Identifiable {
    let id = UUID(); let title: String; let text: String
}

struct HelpView: View {
    @EnvironmentObject var store: Store
    private let sections: [HelpSection] = [
        HelpSection(title: "Quick start", text: "Log a petrol fill-up, add snacks for family members, and record water cans you buy. The Today tab shows your score, streak and reward."),
        HelpSection(title: "Petrol", text: "Enter amount and price per litre; litres are calculated. Add the odometer reading to get mileage (km/l) and cost per km. Mileage assumes full-tank fills."),
        HelpSection(title: "Snacks & family", text: "Add family members, pick one, and tap a quick preset (biscuits, chips...) or enter your own. If nothing was bought, tap 'No snacks today' so the day still counts."),
        HelpSection(title: "Water", text: "Set how many days a can lasts in Settings. The app estimates days left. When days left drops to your 'buy early' setting, you get ONE reminder per day at your chosen time (morning, afternoon or evening). Buying a can cancels the reminders."),
        HelpSection(title: "Score and pass marks", text: "Each day: water ready = 40, snacks logged = 30, within daily budget = 30. Default pass mark is 60. Passing days build your streak and unlock a daily reward."),
        HelpSection(title: "Reports", text: "Monthly spending chart, a 28-day pass/fail calendar, per-person snack totals. Use Copy report or Copy CSV to paste anywhere."),
        HelpSection(title: "Screenshot and recording", text: "Use the toolbar buttons. Files are saved on your Desktop. macOS asks for Screen Recording permission once."),
        HelpSection(title: "Privacy", text: "All data stays on this Mac in ~/Library/Application Support/HomeTrack/. Nothing is uploaded."),
        HelpSection(title: "Troubleshooting", text: "No reminders? Allow notifications in System Settings > Notifications > HomeTrack, then press 'Save & schedule' in Settings. App won't open the first time? Right-click it and choose Open.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    PageTitle(text: "Help")
                    Spacer()
                    Button("Show onboarding again") { store.s.onboarded = false }
                }
                ForEach(sections) { sec in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sec.title).font(.headline)
                        Text(sec.text).textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }
            }
            .padding(24)
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var store: Store
    @State private var step = 0
    private let steps: [(String, String, String)] = [
        ("hand.wave.fill", "Welcome to HomeTrack", "Track petrol, family snacks and drinking water in one calm place."),
        ("fuelpump.fill", "Petrol and snacks", "Log fill-ups with the odometer for mileage. Add family members and log biscuits and snacks per person."),
        ("drop.fill", "Water, without forgetting", "Tell the app how long a can lasts. It will recommend buying early and remind you once, at your preferred time, only when needed."),
        ("checkmark.seal.fill", "Daily score and pass marks", "Each day earns a score out of 100. Reach the pass mark to build streaks and claim daily rewards."),
        ("lock.shield.fill", "Private by design", "Everything stays on your Mac. You can copy any report, record your screen, and use dark mode.")
    ]

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: steps[step].0).font(.system(size: 54)).foregroundStyle(Color.teal)
            Text(steps[step].1).font(.title.bold())
            Text(steps[step].2).multilineTextAlignment(.center).frame(maxWidth: 420)
            HStack {
                Button("Back") { step -= 1 }.disabled(step == 0)
                Spacer()
                Text("\(step + 1) / \(steps.count)").foregroundStyle(.secondary)
                Spacer()
                if step < steps.count - 1 {
                    Button("Next") { step += 1 }.buttonStyle(.borderedProminent).tint(.teal)
                } else {
                    Button("Get started") { store.s.onboarded = true }.buttonStyle(.borderedProminent).tint(.teal)
                }
            }
            Button("Skip") { store.s.onboarded = true }.buttonStyle(.link)
        }
        .padding(32)
        .frame(width: 520)
    }
}

// MARK: - AI prompts
struct PromptsView: View {
    @EnvironmentObject var store: Store
    private let prompts: [(String, String)] = [
        ("Analyse my petrol use", "Here is my petrol data as CSV. Calculate my average mileage and cost per km, find unusual fill-ups, and suggest 5 practical ways to lower my fuel cost. Data:\n[paste CSV here]"),
        ("Improve my mileage", "I ride/drive a [vehicle model]. My mileage is [x] km/l. Give me a checklist to improve it (tyre pressure, service, riding habits) with realistic expected gains."),
        ("Family snack budget", "We are [n] people in the family. We spend about ₹[x] a month on biscuits and snacks. Suggest a healthy weekly snack plan within ₹[y] a month and a simple way to track it per person."),
        ("Water can planning", "A 20-litre water can lasts [n] days in our home of [people] people. Suggest how many cans to keep in stock, when to reorder, and how to avoid running out during holidays."),
        ("Monthly review", "Here is my HomeTrack report. Summarise it in 5 bullet points, tell me where I overspent, and suggest one goal for next month:\n[paste report here]"),
        ("Set pass marks", "My daily score is out of 100 (water ready 40, snacks logged 30, within budget 30). Is a pass mark of [x] reasonable for a family of [n]? Suggest a way to adjust it fairly."),
        ("Cut household costs", "My monthly spend is: petrol ₹[a], snacks ₹[b], water ₹[c]. Suggest realistic ways to cut each by 10 percent without hurting daily comfort."),
        ("Explain my report", "Explain this report in simple words as if I'm new to budgeting, and give me three small habits to start this week:\n[paste report here]")
    ]

    private func claudeURL(_ text: String) -> URL? {
        let enc = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://claude.ai/new?q=" + enc)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PageTitle(text: "AI Prompts")
                Text("Copy a prompt, paste your data (use Reports > Copy CSV or Copy report), and ask any AI assistant.")
                    .foregroundStyle(.secondary)
                HStack {
                    CopyButton(title: "Copy report now", text: store.reportText())
                    CopyButton(title: "Copy CSV now", text: store.csv())
                }
                ForEach(prompts, id: \.0) { p in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(p.0).font(.headline)
                        Text(p.1).font(.callout).textSelection(.enabled)
                        HStack {
                            CopyButton(title: "Copy prompt", text: p.1)
                            Button("Open in Claude") {
                                if let u = claudeURL(p.1) { NSWorkspace.shared.open(u) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }
            }
            .padding(24)
        }
    }
}

// MARK: - GitHub
struct GitHubView: View {
    private let repo = "https://github.com/theikbhal/hometrack-mac"
    private let clone = "git clone https://github.com/theikbhal/hometrack-mac.git"

    private func open(_ s: String) { if let u = URL(string: s) { NSWorkspace.shared.open(u) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageTitle(text: "GitHub")
                VStack(alignment: .leading, spacing: 10) {
                    Text("Open source").font(.headline)
                    Text(repo).textSelection(.enabled)
                    HStack {
                        Button("Open repository") { open(repo) }.buttonStyle(.borderedProminent).tint(.teal)
                        Button("Report an issue") { open(repo + "/issues/new") }
                        Button("Star ⭐") { open(repo) }
                        CopyButton(title: "Copy link", text: repo)
                    }
                }
                .card()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Build it yourself").font(.headline)
                    Text(clone).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                    Text("cd hometrack-mac && ./install.sh").font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                    CopyButton(title: "Copy clone command", text: clone)
                    Text("Needs macOS 13+ and Xcode. The script builds the app, installs it to Applications and adds a Desktop shortcut.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .card()
            }
            .padding(24)
        }
    }
}

// MARK: - Settings
struct SettingsView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageTitle(text: "Settings")

                VStack(alignment: .leading, spacing: 10) {
                    Text("Appearance").font(.headline)
                    Picker("", selection: $store.s.appearance) {
                        Text("System").tag(0); Text("Light").tag(1); Text("Dark").tag(2)
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 320)
                }
                .card()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Water").font(.headline)
                    Stepper("Price per can: ₹\(Int(store.s.waterPrice))", value: $store.s.waterPrice, in: 5...300, step: 5)
                    Stepper("One can lasts: \(store.s.canLasts) day(s)", value: $store.s.canLasts, in: 1...30)
                    Stepper("Buy early: remind when \(store.s.recommendDays) day(s) or less left", value: $store.s.recommendDays, in: 1...7)
                    Picker("Reminder time", selection: $store.s.waterSlot) {
                        Text("Morning (8 am)").tag(0)
                        Text("Afternoon (2 pm)").tag(1)
                        Text("Evening (6 pm)").tag(2)
                    }
                    .pickerStyle(.segmented).frame(maxWidth: 460)
                    Toggle("Water reminders", isOn: $store.s.remindWater)
                }
                .card()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Score and budget").font(.headline)
                    Stepper("Daily budget: ₹\(Int(store.s.dailyBudget))", value: $store.s.dailyBudget, in: 50...10000, step: 50)
                    Stepper("Pass mark: \(store.s.passMark) / 100", value: $store.s.passMark, in: 10...100, step: 10)
                    Toggle("Daily check-in reminder", isOn: $store.s.remindCheckin)
                    Stepper("Check-in hour: \(store.s.checkinHour):00", value: $store.s.checkinHour, in: 0...23)
                }
                .card()

                HStack {
                    Button("Save & schedule reminders") { store.requestAuth(); store.reschedule() }
                        .buttonStyle(.borderedProminent).tint(.teal)
                    Button("Screenshot") { Capture.shot() }
                    Button(store.recording ? "Stop recording" : "Start recording") { store.toggleRecord() }
                }
                Text("Screenshots and recordings go to your Desktop. Time in app counts only while HomeTrack is frontmost.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .onDisappear { store.reschedule() }
    }
}
