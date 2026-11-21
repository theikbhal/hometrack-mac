import SwiftUI
import AppKit
import UserNotifications

struct PetrolEntry: Codable, Identifiable {
    var id = UUID(); var date: Date; var litres: Double; var price: Double
    var amount: Double; var odometer: Double?; var note: String
}
struct SnackEntry: Codable, Identifiable {
    var id = UUID(); var date: Date; var member: String; var item: String; var qty: Int; var cost: Double
}
struct WaterEntry: Codable, Identifiable {
    var id = UUID(); var date: Date; var cans: Int; var cost: Double; var shop: String
}
struct NotePage: Codable, Identifiable {
    var id = UUID(); var title: String; var body: String
}

enum Cat: String, CaseIterable, Identifiable {
    case petrol = "Petrol", snacks = "Snacks", water = "Water"
    var id: String { rawValue }
}

struct MonthStat: Identifiable {
    var id: String { "\(month.timeIntervalSince1970)-\(cat)" }
    let month: Date
    let cat: String
    let amount: Double
}

struct AppState: Codable {
    var petrol: [PetrolEntry] = []
    var snacks: [SnackEntry] = []
    var water: [WaterEntry] = []
    var notes: [NotePage] = [NotePage(title: "My first page", body: "Write anything here.")]
    var members: [String] = ["Me"]
    var waterStock = 0
    var canStarted: Date? = nil
    var waterPrice = 40.0
    var canLasts = 3
    var recommendDays = 2
    var waterSlot = 0            // 0 morning, 1 afternoon, 2 evening
    var remindWater = true
    var remindCheckin = true
    var checkinHour = 21
    var dailyBudget = 500.0
    var passMark = 60
    var coins = 0
    var lastClaim: Date? = nil
    var appearance = 0           // 0 system, 1 light, 2 dark
    var onboarded = false
    var snackNoneDay = ""
}

func dayKey(_ d: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
}

func copyToClipboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

final class Store: ObservableObject {
    @Published var s: AppState { didSet { save() } }
    @Published var scores: [String: Int]
    @Published var recording = false
    private var rec: Process?
    private let stateURL: URL
    private let scoreURL: URL
    private var cal: Calendar { Calendar.current }

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HomeTrack", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        stateURL = dir.appendingPathComponent("state.json")
        scoreURL = dir.appendingPathComponent("scores.json")
        if let d = try? Data(contentsOf: stateURL), let st = try? JSONDecoder().decode(AppState.self, from: d) {
            s = st
        } else {
            s = AppState()
        }
        if let d = try? Data(contentsOf: scoreURL), let sc = try? JSONDecoder().decode([String: Int].self, from: d) {
            scores = sc
        } else {
            scores = [:]
        }
        updateScore()
    }

    private func save() {
        if let d = try? JSONEncoder().encode(s) { try? d.write(to: stateURL) }
        updateScore()
    }

    func updateScore() {
        let k = dayKey(Date())
        let sc = score
        if scores[k] != sc {
            scores[k] = sc
            if let d = try? JSONEncoder().encode(scores) { try? d.write(to: scoreURL) }
        }
    }

    var scheme: ColorScheme? { s.appearance == 1 ? .light : (s.appearance == 2 ? .dark : nil) }

    // MARK: spending
    private func isToday(_ d: Date) -> Bool { cal.isDateInToday(d) }
    private func inMonth(_ d: Date) -> Bool { cal.isDate(d, equalTo: Date(), toGranularity: .month) }

    var spendToday: Double {
        s.petrol.filter { isToday($0.date) }.reduce(0) { $0 + $1.amount }
        + s.snacks.filter { isToday($0.date) }.reduce(0) { $0 + $1.cost }
        + s.water.filter { isToday($0.date) }.reduce(0) { $0 + $1.cost }
    }

    func monthTotal(_ c: Cat) -> Double {
        switch c {
        case .petrol: return s.petrol.filter { inMonth($0.date) }.reduce(0) { $0 + $1.amount }
        case .snacks: return s.snacks.filter { inMonth($0.date) }.reduce(0) { $0 + $1.cost }
        case .water: return s.water.filter { inMonth($0.date) }.reduce(0) { $0 + $1.cost }
        }
    }

    var monthGrand: Double { Cat.allCases.reduce(0) { $0 + monthTotal($1) } }

    func monthlyStats(_ n: Int) -> [MonthStat] {
        var out: [MonthStat] = []
        let start = cal.dateInterval(of: .month, for: Date())!.start
        for i in (0..<n).reversed() {
            let m = cal.date(byAdding: .month, value: -i, to: start)!
            for c in Cat.allCases {
                let amt: Double
                switch c {
                case .petrol: amt = s.petrol.filter { cal.isDate($0.date, equalTo: m, toGranularity: .month) }.reduce(0) { $0 + $1.amount }
                case .snacks: amt = s.snacks.filter { cal.isDate($0.date, equalTo: m, toGranularity: .month) }.reduce(0) { $0 + $1.cost }
                case .water: amt = s.water.filter { cal.isDate($0.date, equalTo: m, toGranularity: .month) }.reduce(0) { $0 + $1.cost }
                }
                out.append(MonthStat(month: m, cat: c.rawValue, amount: amt))
            }
        }
        return out
    }

    func snackByMember() -> [(String, Double)] {
        s.members.map { name in
            (name, s.snacks.filter { $0.member == name && inMonth($0.date) }.reduce(0) { $0 + $1.cost })
        }
    }

    var mileage: (kmPerL: Double, costPerKm: Double)? {
        let list = s.petrol.filter { $0.odometer != nil }.sorted { $0.date < $1.date }
        guard list.count >= 2 else { return nil }
        var km = 0.0, l = 0.0, cost = 0.0
        for i in 1..<list.count {
            let d = (list[i].odometer ?? 0) - (list[i - 1].odometer ?? 0)
            if d > 0 { km += d; l += list[i].litres; cost += list[i].amount }
        }
        guard km > 0, l > 0 else { return nil }
        return (km / l, cost / km)
    }

    // MARK: water
    private func daysSince(_ d: Date) -> Int {
        cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: Date())).day ?? 0
    }

    var waterDaysLeft: Int {
        guard s.waterStock > 0 else { return 0 }
        let started = s.canStarted ?? Date()
        return (s.waterStock - 1) * s.canLasts + max(0, s.canLasts - daysSince(started))
    }

    var waterNeedsBuy: Bool { waterDaysLeft <= s.recommendDays }

    var waterAdvice: String {
        if s.waterStock == 0 { return "No water can at home. Buy one now." }
        if waterDaysLeft <= 1 { return "Buy today. Morning is best." }
        if waterDaysLeft <= s.recommendDays { return "Buy early: order by tomorrow so you never run out." }
        return "Water is fine for about \(waterDaysLeft) days."
    }

    func buyWater(cans: Int, shop: String) {
        if s.waterStock == 0 || s.canStarted == nil { s.canStarted = Date() }
        s.waterStock += cans
        s.water.append(WaterEntry(date: Date(), cans: cans, cost: s.waterPrice * Double(cans), shop: shop))
        reschedule()
    }

    func openNewCan() {
        guard s.waterStock > 0 else { return }
        s.waterStock -= 1
        s.canStarted = Date()
        reschedule()
    }

    // MARK: logging
    func addPetrol(amount: Double, price: Double, odometer: Double?, note: String) {
        guard amount > 0, price > 0 else { return }
        s.petrol.append(PetrolEntry(date: Date(), litres: amount / price, price: price,
                                    amount: amount, odometer: odometer, note: note))
        reschedule()
    }

    func addSnack(member: String, item: String, qty: Int, cost: Double) {
        guard cost > 0 else { return }
        s.snacks.append(SnackEntry(date: Date(), member: member, item: item.isEmpty ? "Snack" : item, qty: max(qty, 1), cost: cost))
        reschedule()
    }

    func markNoSnacks() { s.snackNoneDay = dayKey(Date()); reschedule() }

    // MARK: score, streak, reward
    var waterReady: Bool { s.waterStock > 0 }
    var snacksDone: Bool { s.snackNoneDay == dayKey(Date()) || s.snacks.contains { isToday($0.date) } }
    var budgetOK: Bool { spendToday <= s.dailyBudget }
    var score: Int { (waterReady ? 40 : 0) + (snacksDone ? 30 : 0) + (budgetOK ? 30 : 0) }
    var passedToday: Bool { score >= s.passMark }

    var streak: Int {
        var day = cal.startOfDay(for: Date())
        if (scores[dayKey(day)] ?? 0) < s.passMark { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var n = 0
        while (scores[dayKey(day)] ?? -1) >= s.passMark { n += 1; day = cal.date(byAdding: .day, value: -1, to: day)! }
        return n
    }

    func lastDays(_ n: Int) -> [Date] {
        let today = cal.startOfDay(for: Date())
        return (0..<n).reversed().map { cal.date(byAdding: .day, value: -$0, to: today)! }
    }

    var rewardAmount: Int { passedToday ? 10 + min(streak, 30) + (score == 100 ? 5 : 0) : 0 }
    var canClaim: Bool {
        guard passedToday else { return false }
        if let l = s.lastClaim, cal.isDateInToday(l) { return false }
        return true
    }
    func claim() {
        guard canClaim else { return }
        s.coins += rewardAmount
        s.lastClaim = Date()
    }

    // MARK: text exports
    func reportText() -> String {
        var t = "HomeTrack report, \(dayKey(Date()))\n"
        t += "This month: Petrol ₹\(Int(monthTotal(.petrol))), Snacks ₹\(Int(monthTotal(.snacks))), Water ₹\(Int(monthTotal(.water))), Total ₹\(Int(monthGrand))\n"
        if let m = mileage { t += String(format: "Mileage: %.1f km/l, cost per km ₹%.2f\n", m.kmPerL, m.costPerKm) }
        t += "Water: \(s.waterStock) can(s), about \(waterDaysLeft) day(s) left. \(waterAdvice)\n"
        t += "Today's score: \(score)/100 (pass mark \(s.passMark)), streak \(streak) day(s)\n"
        let by = snackByMember().filter { $0.1 > 0 }
        if !by.isEmpty { t += "Snacks by person: " + by.map { "\($0.0) ₹\(Int($0.1))" }.joined(separator: ", ") + "\n" }
        return t
    }

    func csv() -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]
        var out = "type,date,who_or_shop,item,qty_or_litres,amount\n"
        for e in s.petrol { out += "petrol,\(f.string(from: e.date)),,fuel,\(String(format: "%.2f", e.litres)),\(e.amount)\n" }
        for e in s.snacks { out += "snack,\(f.string(from: e.date)),\(e.member),\(e.item),\(e.qty),\(e.cost)\n" }
        for e in s.water { out += "water,\(f.string(from: e.date)),\(e.shop),can,\(e.cans),\(e.cost)\n" }
        return out
    }

    // MARK: screen capture
    func toggleRecord() {
        if recording {
            rec?.interrupt(); rec = nil; recording = false
        } else {
            rec = Capture.run(["-v", Capture.desktop("HomeTrack-\(Capture.stamp()).mov")])
            recording = true
        }
    }

    // MARK: notifications
    func requestAuth() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // One reminder per slot, only when needed, and everything is cleared and rebuilt after any change.
    func reschedule() {
        let c = UNUserNotificationCenter.current()
        c.removeAllPendingNotificationRequests()

        func add(_ id: String, _ title: String, _ body: String, _ comps: DateComponents) {
            let content = UNMutableNotificationContent()
            content.title = title; content.body = body; content.sound = .default
            c.add(UNNotificationRequest(identifier: id, content: content,
                                        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
        func slot(_ offset: Int, _ hour: Int) -> DateComponents? {
            guard let day = cal.date(byAdding: .day, value: offset, to: Date()) else { return nil }
            var comps = cal.dateComponents([.year, .month, .day], from: day)
            comps.hour = hour; comps.minute = 0
            guard let fire = cal.date(from: comps), fire > Date() else { return nil }
            return comps
        }

        if s.remindWater && waterNeedsBuy {
            let hours = [8, 14, 18]
            let hour = hours[min(max(s.waterSlot, 0), 2)]
            for i in 0..<3 {
                if let comps = slot(i, hour) { add("water\(i)", "Buy water can 💧", waterAdvice, comps) }
            }
        }
        if s.remindCheckin {
            for i in 0..<7 {
                if i == 0 && passedToday { continue }
                if let comps = slot(i, s.checkinHour) {
                    add("checkin\(i)", "Daily check-in", "Log snacks and check water to keep your streak.", comps)
                }
            }
        }
    }
}

// Tracks time while the app is frontmost
final class TimeTracker: ObservableObject {
    @Published var total: Int
    @Published var today: Int
    private var key: String
    private var timer: Timer?
    private var ticks = 0

    init() {
        let k = dayKey(Date())
        key = k
        total = UserDefaults.standard.integer(forKey: "totalSeconds")
        let map = UserDefaults.standard.dictionary(forKey: "dailySeconds") as? [String: Int] ?? [:]
        today = map[k] ?? 0
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.persist() }
    }

    private func tick() {
        guard NSApplication.shared.isActive else { return }
        let k = dayKey(Date())
        if k != key {
            persist()
            key = k
            let map = UserDefaults.standard.dictionary(forKey: "dailySeconds") as? [String: Int] ?? [:]
            today = map[k] ?? 0
        }
        total += 1; today += 1; ticks += 1
        if ticks % 10 == 0 { persist() }
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(total, forKey: "totalSeconds")
        var map = d.dictionary(forKey: "dailySeconds") as? [String: Int] ?? [:]
        map[key] = today
        d.set(map, forKey: "dailySeconds")
    }
}

enum Capture {
    static func stamp() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmmss"; return f.string(from: Date())
    }
    static func desktop(_ name: String) -> String { NSHomeDirectory() + "/Desktop/" + name }

    @discardableResult
    static func run(_ args: [String]) -> Process {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = args
        try? p.run()
        return p
    }

    static func shot() {
        var a = ["-x"]
        if let n = NSApp.keyWindow?.windowNumber, n > 0 { a += ["-l", "\(n)"] }
        a.append(desktop("HomeTrack-\(stamp()).png"))
        run(a)
    }
}
