import SwiftUI
import AppKit

enum Tab: String, CaseIterable, Identifiable {
    case today = "Today"
    case petrol = "Petrol"
    case snacks = "Snacks & Family"
    case water = "Water"
    case reports = "Reports"
    case calc = "Calculator"
    case pages = "My Pages"
    case help = "Help"
    case prompts = "AI Prompts"
    case github = "GitHub"
    case settings = "Settings"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .today: return "sun.max.fill"
        case .petrol: return "fuelpump.fill"
        case .snacks: return "takeoutbag.and.cup.and.straw.fill"
        case .water: return "drop.fill"
        case .reports: return "chart.bar.fill"
        case .calc: return "plusminus.circle.fill"
        case .pages: return "doc.text.fill"
        case .help: return "questionmark.circle.fill"
        case .prompts: return "sparkles"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .settings: return "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var tracker: TimeTracker
    @State private var tab: Tab? = .today
    private let minute = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                BrandHeader().padding()
                List(selection: $tab) {
                    ForEach(Tab.allCases) { t in
                        Label(t.rawValue, systemImage: t.icon).tag(t)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time in app").font(.caption).foregroundStyle(.secondary)
                    Text("Today \(fmtLong(tracker.today))").font(.callout.monospacedDigit())
                    Text("Total \(fmtLong(tracker.total))").font(.callout.monospacedDigit())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            ZStack {
                AnimatedBackground()
                detail
            }
            .toolbar {
                ToolbarItemGroup {
                    Button { Capture.shot() } label: { Label("Screenshot", systemImage: "camera.fill") }
                    Button { store.toggleRecord() } label: {
                        Label(store.recording ? "Stop" : "Record",
                              systemImage: store.recording ? "stop.circle.fill" : "record.circle")
                    }
                }
            }
        }
        .sheet(isPresented: Binding(get: { !store.s.onboarded }, set: { _ in })) {
            OnboardingView().environmentObject(store)
        }
        .onAppear { store.requestAuth(); store.updateScore(); store.reschedule() }
        .onReceive(minute) { _ in store.updateScore() }
    }

    @ViewBuilder private var detail: some View {
        switch tab ?? .today {
        case .today: TodayView()
        case .petrol: PetrolView()
        case .snacks: SnacksView()
        case .water: WaterView()
        case .reports: ReportsView()
        case .calc: CalcView()
        case .pages: PagesView()
        case .help: HelpView()
        case .prompts: PromptsView()
        case .github: GitHubView()
        case .settings: SettingsView()
        }
    }
}

// MARK: - Today
struct TodayView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var tracker: TimeTracker

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 12 ? "Good morning" : (h < 18 ? "Good afternoon" : "Good evening")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    PageTitle(text: greeting)
                    Spacer()
                    CopyButton(title: "Copy summary", text: store.reportText())
                    ShareLink(item: store.reportText()) { Label("Share", systemImage: "square.and.arrow.up") }
                }
                HStack(spacing: 12) {
                    StatTile(icon: "flame.fill", title: "Pass streak (days)", value: "\(store.streak)", tint: .orange)
                    StatTile(icon: "star.circle.fill", title: "Coins", value: "\(store.s.coins)", tint: .yellow)
                    StatTile(icon: "indianrupeesign.circle", title: "Spent today", value: rs(store.spendToday), tint: .teal)
                    StatTile(icon: "clock.fill", title: "In app today", value: fmtLong(tracker.today), tint: .blue)
                }
                HStack(alignment: .top, spacing: 16) {
                    ScoreCard()
                    VStack(spacing: 16) {
                        RewardCard()
                        WaterBanner()
                    }
                }
                QuickActions()
            }
            .padding(24)
        }
    }
}

struct ScoreCard: View {
    @EnvironmentObject var store: Store
    private func row(_ done: Bool, _ title: String, _ pts: Int) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.green : Color.secondary)
            Text(title)
            Spacer()
            Text("\(pts) pts").foregroundStyle(.secondary)
        }
    }
    var body: some View {
        VStack(spacing: 14) {
            Text("Today's score").font(.headline)
            ZStack {
                Circle().stroke(Color.gray.opacity(0.2), lineWidth: 12)
                Circle().trim(from: 0, to: CGFloat(store.score) / 100)
                    .stroke(store.passedToday ? Color.green : Color.orange,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(), value: store.score)
                VStack {
                    Text("\(store.score)").font(.system(size: 40, weight: .bold, design: .rounded))
                    Text(store.passedToday ? "PASS ✅" : "Below pass mark \(store.s.passMark)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, height: 150)
            VStack(spacing: 8) {
                row(store.waterReady, "Water ready at home", 40)
                row(store.snacksDone, "Snacks logged (or none today)", 30)
                row(store.budgetOK, "Within daily budget \(rs(store.s.dailyBudget))", 30)
            }
        }
        .frame(maxWidth: .infinity)
        .card()
    }
}

struct RewardCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Daily reward", systemImage: "gift.fill").font(.headline)
            if store.canClaim {
                Text("You passed today. Claim \(store.rewardAmount) coins.")
            } else if store.passedToday {
                Text("Claimed for today ✅ See you tomorrow.")
            } else {
                Text("Reach the pass mark (\(store.s.passMark)) to unlock today's reward.")
            }
            Button("Claim") { withAnimation { store.claim() } }
                .disabled(!store.canClaim).buttonStyle(.borderedProminent).tint(.yellow)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct WaterBanner: View {
    @EnvironmentObject var store: Store
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Water", systemImage: "drop.fill").font(.headline)
            Text(store.waterAdvice).foregroundStyle(store.waterNeedsBuy ? Color.orange : Color.secondary)
            Text("Stock: \(store.s.waterStock) can(s), about \(store.waterDaysLeft) day(s) left")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct QuickActions: View {
    @EnvironmentObject var store: Store
    var body: some View {
        HStack(spacing: 10) {
            Button("+1 water can") { store.buyWater(cans: 1, shop: "") }
            Button("Opened a new can") { store.openNewCan() }.disabled(store.s.waterStock == 0)
            Button("No snacks today") { store.markNoSnacks() }
            Spacer()
        }
        .card()
    }
}

// MARK: - Petrol
struct PetrolView: View {
    @EnvironmentObject var store: Store
    @State private var amount = ""
    @State private var price = ""
    @State private var odo = ""
    @State private var note = ""

    private var litres: Double {
        let a = Double(amount) ?? 0, p = Double(price) ?? 0
        return p > 0 ? a / p : 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageTitle(text: "Petrol")
                HStack(spacing: 12) {
                    StatTile(icon: "indianrupeesign.circle", title: "This month", value: rs(store.monthTotal(.petrol)), tint: .teal)
                    StatTile(icon: "speedometer", title: "Avg mileage", value: store.mileage.map { String(format: "%.1f km/l", $0.kmPerL) } ?? "needs 2 fills", tint: .green)
                    StatTile(icon: "road.lanes", title: "Cost per km", value: store.mileage.map { rs($0.costPerKm, 2) } ?? "-", tint: .orange)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Add fill-up").font(.headline)
                    HStack {
                        TextField("Amount ₹", text: $amount).textFieldStyle(.roundedBorder)
                        TextField("Price per litre ₹", text: $price).textFieldStyle(.roundedBorder)
                        TextField("Odometer km (optional)", text: $odo).textFieldStyle(.roundedBorder)
                        TextField("Note", text: $note).textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("Litres: \(String(format: "%.2f", litres))").foregroundStyle(.secondary)
                        Spacer()
                        Button("Add") {
                            store.addPetrol(amount: Double(amount) ?? 0, price: Double(price) ?? 0,
                                            odometer: Double(odo), note: note)
                            amount = ""; odo = ""; note = ""
                        }
                        .buttonStyle(.borderedProminent).tint(.teal)
                        .disabled(litres <= 0)
                    }
                    Text("Mileage assumes you fill the tank each time and enter the odometer.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .card()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent fill-ups").font(.headline)
                    ForEach(Array(store.s.petrol.sorted { $0.date > $1.date }.prefix(15))) { e in
                        HStack {
                            Text(e.date, style: .date).frame(width: 110, alignment: .leading)
                            Text(String(format: "%.2f L", e.litres)).frame(width: 80, alignment: .leading)
                            Text(rs(e.price, 2) + "/L").frame(width: 90, alignment: .leading)
                            Text(rs(e.amount)).bold().frame(width: 80, alignment: .leading)
                            Text(e.odometer.map { "\(Int($0)) km" } ?? "").foregroundStyle(.secondary)
                            Spacer()
                            Text(e.note).foregroundStyle(.secondary)
                            Button { store.s.petrol.removeAll { $0.id == e.id } } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                        }
                        .font(.callout)
                    }
                    if store.s.petrol.isEmpty { Text("No fill-ups yet.").foregroundStyle(.secondary) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
            .padding(24)
        }
        .onAppear {
            if price.isEmpty, let last = store.s.petrol.last { price = String(format: "%.2f", last.price) }
        }
    }
}

// MARK: - Snacks & family
struct SnacksView: View {
    @EnvironmentObject var store: Store
    @State private var member = ""
    @State private var item = ""
    @State private var qty = "1"
    @State private var cost = ""
    @State private var newMember = ""
    private let presets: [(String, Double)] = [("Biscuits", 10), ("Chips", 20), ("Chocolate", 10),
                                              ("Tea snack", 15), ("Fruit", 30), ("Ice cream", 20)]
    private var who: String {
        store.s.members.contains(member) ? member : (store.s.members.first ?? "Me")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageTitle(text: "Snacks & Family")
                HStack(spacing: 12) {
                    StatTile(icon: "indianrupeesign.circle", title: "This month", value: rs(store.monthTotal(.snacks)), tint: .teal)
                    StatTile(icon: "person.2.fill", title: "Family members", value: "\(store.s.members.count)", tint: .purple)
                    StatTile(icon: "checkmark.circle", title: "Logged today", value: store.snacksDone ? "Yes" : "Not yet", tint: .green)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quick add for").font(.headline)
                    Picker("", selection: $member) {
                        ForEach(store.s.members, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                        ForEach(presets, id: \.0) { p in
                            Button("\(p.0) \(rs(p.1))") {
                                store.addSnack(member: who, item: p.0, qty: 1, cost: p.1)
                            }
                        }
                    }
                    Divider()
                    HStack {
                        TextField("Item", text: $item).textFieldStyle(.roundedBorder)
                        TextField("Qty", text: $qty).textFieldStyle(.roundedBorder).frame(width: 60)
                        TextField("Total ₹", text: $cost).textFieldStyle(.roundedBorder).frame(width: 100)
                        Button("Add") {
                            store.addSnack(member: who, item: item, qty: Int(qty) ?? 1, cost: Double(cost) ?? 0)
                            item = ""; cost = ""; qty = "1"
                        }
                        .buttonStyle(.borderedProminent).tint(.teal).disabled((Double(cost) ?? 0) <= 0)
                    }
                    Button("No snacks today") { store.markNoSnacks() }
                }
                .card()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Family members").font(.headline)
                    HStack {
                        ForEach(store.s.members, id: \.self) { m in
                            HStack(spacing: 4) {
                                Text(m)
                                if store.s.members.count > 1 {
                                    Button { store.s.members.removeAll { $0 == m } } label: { Image(systemName: "xmark.circle.fill") }
                                        .buttonStyle(.borderless)
                                }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.teal.opacity(0.18), in: Capsule())
                        }
                        Spacer()
                    }
                    HStack {
                        TextField("Add member (name)", text: $newMember).textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                        Button("Add member") {
                            let n = newMember.trimmingCharacters(in: .whitespaces)
                            if !n.isEmpty && !store.s.members.contains(n) { store.s.members.append(n) }
                            newMember = ""
                        }
                    }
                    Divider()
                    Text("This month by person").font(.subheadline.bold())
                    ForEach(store.snackByMember(), id: \.0) { row in
                        HStack { Text(row.0); Spacer(); Text(rs(row.1)).monospacedDigit() }
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent").font(.headline)
                    ForEach(Array(store.s.snacks.sorted { $0.date > $1.date }.prefix(15))) { e in
                        HStack {
                            Text(e.date, style: .date).frame(width: 110, alignment: .leading)
                            Text(e.member).frame(width: 90, alignment: .leading)
                            Text("\(e.item) × \(e.qty)")
                            Spacer()
                            Text(rs(e.cost)).bold()
                            Button { store.s.snacks.removeAll { $0.id == e.id } } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                        }
                        .font(.callout)
                    }
                    if store.s.snacks.isEmpty { Text("Nothing logged yet.").foregroundStyle(.secondary) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
            .padding(24)
        }
        .onAppear { if member.isEmpty { member = store.s.members.first ?? "Me" } }
    }
}

// MARK: - Water
struct WaterView: View {
    @EnvironmentObject var store: Store
    @State private var cans = 1
    @State private var shop = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageTitle(text: "Water")
                HStack(spacing: 12) {
                    StatTile(icon: "shippingbox.fill", title: "Cans at home", value: "\(store.s.waterStock)", tint: store.s.waterStock == 0 ? .red : .blue)
                    StatTile(icon: "calendar", title: "Days left (est.)", value: "\(store.waterDaysLeft)", tint: store.waterNeedsBuy ? .orange : .green)
                    StatTile(icon: "indianrupeesign.circle", title: "This month", value: rs(store.monthTotal(.water)), tint: .teal)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label(store.waterAdvice, systemImage: store.waterNeedsBuy ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(store.waterNeedsBuy ? Color.orange : Color.green)
                    Text("Reminder: \(["morning (8 am)", "afternoon (2 pm)", "evening (6 pm)"][min(max(store.s.waterSlot, 0), 2)]), only while stock is low, and cancelled as soon as you buy.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Bought water").font(.headline)
                    HStack {
                        Stepper("Cans: \(cans)", value: $cans, in: 1...20).frame(maxWidth: 160)
                        TextField("Shop name (optional)", text: $shop).textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                        Text("= \(rs(store.s.waterPrice * Double(cans)))").foregroundStyle(.secondary)
                        Button("Add purchase ✅") { store.buyWater(cans: cans, shop: shop); cans = 1 }
                            .buttonStyle(.borderedProminent).tint(.blue)
                    }
                    HStack {
                        Button("Opened a new can") { store.openNewCan() }.disabled(store.s.waterStock == 0)
                        Text("Tap when the current can is finished and you start the next one.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Find a shop nearby").font(.headline)
                    HStack {
                        Button("Water can suppliers (Maps)") {
                            NSWorkspace.shared.open(URL(string: "http://maps.apple.com/?q=water%20can%20supplier")!)
                        }
                        Button("RO / drinking water plants (Maps)") {
                            NSWorkspace.shared.open(URL(string: "http://maps.apple.com/?q=RO%20water%20plant")!)
                        }
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Purchases").font(.headline)
                    ForEach(Array(store.s.water.sorted { $0.date > $1.date }.prefix(12))) { e in
                        HStack {
                            Text(e.date, style: .date).frame(width: 110, alignment: .leading)
                            Text("\(e.cans) can(s)")
                            Text(e.shop).foregroundStyle(.secondary)
                            Spacer()
                            Text(rs(e.cost)).bold()
                            Button { store.s.water.removeAll { $0.id == e.id } } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                        }
                        .font(.callout)
                    }
                    if store.s.water.isEmpty { Text("No purchases yet.").foregroundStyle(.secondary) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
            .padding(24)
        }
    }
}
