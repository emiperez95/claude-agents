// reminders.swift — a small, fast CRUD CLI over Apple Reminders via EventKit.
//
// Built by the `reminders` wrapper (auto-compiles on first use). All output is
// JSON on stdout; errors are JSON too: {"ok":false,"error":"..."}.
//
// EventKit is linked in-process and queries the store with predicates, so ops
// are ~milliseconds even on large lists (vs. ~seconds/minutes over AppleScript).
//
// Known limits (Apple API, not ours): no "sections within a list", and no
// "flagged" — EventKit exposes neither.

import EventKit
import Foundation

// MARK: - Output helpers

func printJSON(_ obj: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: obj, options: []),
          let s = String(data: data, encoding: .utf8) else {
        print("{\"ok\":false,\"error\":\"failed to serialize output\"}")
        return
    }
    print(s)
}

func fail(_ msg: String) -> Never {
    printJSON(["ok": false, "error": msg])
    exit(1)
}

// MARK: - Date helpers

let outISO: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    f.timeZone = TimeZone(identifier: "UTC")
    return f
}()

func isoOrNull(_ d: Date?) -> Any { d.map { outISO.string(from: $0) } ?? NSNull() }

// Parse a --due value. Returns the date plus whether it should be all-day.
func parseDue(_ s: String) -> (date: Date, allDay: Bool)? {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    if let d = iso.date(from: s) { return (d, false) }
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = iso.date(from: s) { return (d, false) }

    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone.current
    let attempts: [(String, Bool)] = [
        ("yyyy-MM-dd'T'HH:mm:ss", false),
        ("yyyy-MM-dd'T'HH:mm", false),
        ("yyyy-MM-dd HH:mm:ss", false),
        ("yyyy-MM-dd HH:mm", false),
        ("yyyy-MM-dd", true),
    ]
    for (fmt, allDay) in attempts {
        f.dateFormat = fmt
        if let d = f.date(from: s) { return (d, allDay) }
    }
    return nil
}

func dueComponents(from date: Date, allDay: Bool) -> DateComponents {
    let cal = Calendar.current
    return allDay
        ? cal.dateComponents([.year, .month, .day], from: date)
        : cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
}

func dueDate(of r: EKReminder) -> Date? {
    guard let c = r.dueDateComponents else { return nil }
    return Calendar.current.date(from: c)
}

func isAllDay(_ r: EKReminder) -> Bool {
    guard let c = r.dueDateComponents else { return false }
    return c.hour == nil
}

// MARK: - Priority mapping

func priToNum(_ p: String) -> Int {
    switch p.lowercased() {
    case "high": return 1
    case "medium", "med": return 5
    case "low": return 9
    case "none", "0": return 0
    default: return Int(p) ?? 0
    }
}

func numToPri(_ n: Int) -> String {
    switch n {
    case 0: return "none"
    case 1...4: return "high"
    case 5: return "medium"
    default: return "low"
    }
}

// MARK: - Serialization

func serialize(_ r: EKReminder) -> [String: Any] {
    return [
        "id": r.calendarItemIdentifier,
        "title": r.title ?? "",
        "list": r.calendar?.title ?? NSNull(),
        "completed": r.isCompleted,
        "due": isoOrNull(dueDate(of: r)),
        "allday": isAllDay(r),
        "priority": numToPri(r.priority),
        "notes": (r.notes.flatMap { $0.isEmpty ? nil : $0 }) ?? NSNull(),
        "created": isoOrNull(r.creationDate),
    ]
}

// MARK: - EventKit access

let store = EKEventStore()

func requestAccess() {
    let sem = DispatchSemaphore(value: 0)
    var granted = false
    var error: Error?
    if #available(macOS 14.0, *) {
        store.requestFullAccessToReminders { g, e in granted = g; error = e; sem.signal() }
    } else {
        store.requestAccess(to: .reminder) { g, e in granted = g; error = e; sem.signal() }
    }
    sem.wait()
    if !granted {
        fail("Reminders access not granted" + (error.map { ": \($0.localizedDescription)" } ?? "") +
             ". Grant it in System Settings › Privacy & Security › Reminders.")
    }
}

func reminderCalendars() -> [EKCalendar] { store.calendars(for: .reminder) }

func calendar(named name: String) -> EKCalendar? {
    reminderCalendars().first { $0.title == name }
}

func fetch(predicate: NSPredicate) -> [EKReminder] {
    let sem = DispatchSemaphore(value: 0)
    var result: [EKReminder] = []
    store.fetchReminders(matching: predicate) { rems in result = rems ?? []; sem.signal() }
    sem.wait()
    return result
}

func reminder(byId id: String) -> EKReminder? {
    store.calendarItem(withIdentifier: id) as? EKReminder
}

// MARK: - Flag parsing

struct Flags {
    var positional: [String] = []
    var options: [String: String] = [:]
    var bools: Set<String> = []
}

let boolFlagNames: Set<String> = ["all", "include-completed", "allday"]

func parseFlags(_ args: [String]) -> Flags {
    var f = Flags()
    var i = 0
    while i < args.count {
        let a = args[i]
        if a.hasPrefix("--") {
            let key = String(a.dropFirst(2))
            if boolFlagNames.contains(key) {
                f.bools.insert(key)
            } else if i + 1 < args.count && !args[i + 1].hasPrefix("--") {
                f.options[key] = args[i + 1]
                i += 1
            } else {
                f.bools.insert(key)
            }
        } else {
            f.positional.append(a)
        }
        i += 1
    }
    return f
}

// MARK: - Commands

func cmdLists() {
    let cals = reminderCalendars()
    let incomplete = fetch(predicate: store.predicateForIncompleteReminders(
        withDueDateStarting: nil, ending: nil, calendars: nil))
    var counts: [String: Int] = [:]
    for r in incomplete {
        if let id = r.calendar?.calendarIdentifier { counts[id, default: 0] += 1 }
    }
    let def = store.defaultCalendarForNewReminders()
    let rows: [[String: Any]] = cals.map { c in
        ["name": c.title, "id": c.calendarIdentifier, "open": counts[c.calendarIdentifier] ?? 0]
    }
    printJSON(["ok": true, "defaultList": def?.title ?? NSNull(), "lists": rows])
}

func cmdList(_ args: [String]) {
    let f = parseFlags(args)
    let includeCompleted = f.bools.contains("all") || f.bools.contains("include-completed")

    var cals: [EKCalendar]? = nil
    if let name = f.options["list"] {
        guard let c = calendar(named: name) else { fail("list not found: \(name)") }
        cals = [c]
    }

    let predicate = includeCompleted
        ? store.predicateForReminders(in: cals)
        : store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: cals)
    var items = fetch(predicate: predicate)

    if let term = f.options["search"]?.lowercased() {
        items = items.filter {
            ($0.title ?? "").lowercased().contains(term) ||
            ($0.notes ?? "").lowercased().contains(term)
        }
    }

    if let due = f.options["due"] {
        let now = Date()
        let cal = Calendar.current
        items = items.filter { r in
            guard let d = dueDate(of: r) else { return false }
            switch due {
            case "overdue": return d < now && !r.isCompleted
            case "today": return cal.isDateInToday(d)
            case "week":
                let end = now.addingTimeInterval(7 * 86400)
                return d >= cal.startOfDay(for: now) && d <= end
            default: return true
            }
        }
    }

    // Sort: dated first (ascending), undated last.
    items.sort { a, b in
        switch (dueDate(of: a), dueDate(of: b)) {
        case let (da?, db?): return da < db
        case (_?, nil): return true
        case (nil, _?): return false
        default: return false
        }
    }

    let total = items.count
    if let limitStr = f.options["limit"], let limit = Int(limitStr), items.count > limit {
        items = Array(items.prefix(limit))
    }
    printJSON(["ok": true, "count": items.count, "total": total, "reminders": items.map(serialize)])
}

func cmdGet(_ args: [String]) {
    guard let id = args.first else { fail("usage: get <id>") }
    guard let r = reminder(byId: id) else { fail("no reminder with id \(id)") }
    printJSON(["ok": true, "reminder": serialize(r)])
}

func cmdAdd(_ args: [String]) {
    let f = parseFlags(args)
    let title = f.positional.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    let finalTitle = title.isEmpty ? (f.options["title"] ?? "") : title
    if finalTitle.isEmpty { fail("add needs a title (positional text or --title)") }

    let cal: EKCalendar?
    if let name = f.options["list"] {
        guard let c = calendar(named: name) else { fail("list not found: \(name)") }
        cal = c
    } else {
        cal = store.defaultCalendarForNewReminders()
    }
    guard let calendar = cal else { fail("no reminders list available") }

    let r = EKReminder(eventStore: store)
    r.calendar = calendar
    r.title = finalTitle
    if let notes = f.options["notes"] { r.notes = notes }
    if let pri = f.options["priority"] { r.priority = priToNum(pri) }
    if let due = f.options["due"] {
        guard let parsed = parseDue(due) else { fail("could not parse --due (use ISO 8601): \(due)") }
        let allDay = f.bools.contains("allday") || parsed.allDay
        r.dueDateComponents = dueComponents(from: parsed.date, allDay: allDay)
        if !allDay { r.addAlarm(EKAlarm(absoluteDate: parsed.date)) } // so it notifies
    }

    do {
        try store.save(r, commit: true)
        printJSON(["ok": true, "action": "added", "reminder": serialize(r)])
    } catch {
        fail("save failed: \(error.localizedDescription)")
    }
}

func cmdSetCompleted(_ args: [String], _ value: Bool) {
    let ids = args.filter { !$0.hasPrefix("--") }
    if ids.isEmpty { fail("usage: \(value ? "done" : "undone") <id> [<id>...]") }
    var results: [[String: Any]] = []
    for id in ids {
        guard let r = reminder(byId: id) else {
            results.append(["id": id, "ok": false, "error": "not found"]); continue
        }
        r.isCompleted = value
        do {
            try store.save(r, commit: true)
            results.append(["id": id, "ok": true, "title": r.title ?? "", "completed": value])
        } catch {
            results.append(["id": id, "ok": false, "error": error.localizedDescription])
        }
    }
    printJSON(["ok": true, "action": value ? "completed" : "uncompleted", "results": results])
}

func cmdRemove(_ args: [String]) {
    let ids = args.filter { !$0.hasPrefix("--") }
    if ids.isEmpty { fail("usage: rm <id> [<id>...]") }
    var results: [[String: Any]] = []
    for id in ids {
        guard let r = reminder(byId: id) else {
            results.append(["id": id, "ok": false, "error": "not found"]); continue
        }
        let title = r.title ?? ""
        do {
            try store.remove(r, commit: true)
            results.append(["id": id, "ok": true, "title": title])
        } catch {
            results.append(["id": id, "ok": false, "error": error.localizedDescription])
        }
    }
    printJSON(["ok": true, "action": "deleted", "results": results])
}

func cmdEdit(_ args: [String]) {
    let f = parseFlags(args)
    guard let id = f.positional.first else {
        fail("usage: edit <id> [--title ..] [--due ISO|clear] [--notes ..] [--priority ..] [--list NAME]")
    }
    guard let r = reminder(byId: id) else { fail("no reminder with id \(id)") }

    var changed: [String] = []
    if let title = f.options["title"] { r.title = title; changed.append("title") }
    if let notes = f.options["notes"] { r.notes = notes; changed.append("notes") }
    if let pri = f.options["priority"] { r.priority = priToNum(pri); changed.append("priority") }
    if let due = f.options["due"] {
        if due == "clear" {
            r.dueDateComponents = nil
            (r.alarms ?? []).forEach { r.removeAlarm($0) }
            changed.append("due(cleared)")
        } else {
            guard let parsed = parseDue(due) else { fail("could not parse --due: \(due)") }
            let allDay = f.bools.contains("allday") || parsed.allDay
            r.dueDateComponents = dueComponents(from: parsed.date, allDay: allDay)
            (r.alarms ?? []).forEach { r.removeAlarm($0) }
            if !allDay { r.addAlarm(EKAlarm(absoluteDate: parsed.date)) }
            changed.append("due")
        }
    }
    if let name = f.options["list"] {
        guard let c = calendar(named: name) else { fail("target list not found: \(name)") }
        r.calendar = c
        changed.append("list")
    }

    do {
        try store.save(r, commit: true)
        printJSON(["ok": true, "action": "edited", "changed": changed, "reminder": serialize(r)])
    } catch {
        fail("save failed: \(error.localizedDescription)")
    }
}

func help() {
    printJSON([
        "ok": true,
        "usage": [
            "lists": "list all reminder lists with open counts",
            "list": "list [--list NAME] [--search TEXT] [--due overdue|today|week] [--all] [--limit N]",
            "get": "get <id>",
            "add": "add <title...> [--list NAME] [--due ISO] [--allday] [--notes TEXT] [--priority none|low|medium|high]",
            "done": "done <id> [<id>...]   (also: undone)",
            "rm": "rm <id> [<id>...]",
            "edit": "edit <id> [--title ..] [--due ISO|clear] [--notes ..] [--priority ..] [--list NAME]",
        ],
        "notes": "All output is JSON. Dates are ISO 8601 (UTC). No section or flagged support (Apple API limitation).",
    ])
}

// MARK: - Main

let argv = Array(CommandLine.arguments.dropFirst())
let command = argv.first ?? "help"
let rest = Array(argv.dropFirst())

switch command {
case "help", "--help", "-h":
    help()
default:
    requestAccess()
    switch command {
    case "lists": cmdLists()
    case "list", "ls", "show": cmdList(rest)
    case "get": cmdGet(rest)
    case "add", "new": cmdAdd(rest)
    case "done", "complete": cmdSetCompleted(rest, true)
    case "undone", "uncomplete": cmdSetCompleted(rest, false)
    case "rm", "delete": cmdRemove(rest)
    case "edit", "update": cmdEdit(rest)
    default: fail("unknown command: \(command) (try: help)")
    }
}
