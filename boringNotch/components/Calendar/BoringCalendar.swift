//
//  BoringCalendar.swift
//  boringNotch
//
//  Created in NotchNook Pro style (Full 2-column agenda + month grid).
//

import AppKit
import Defaults
import SwiftUI

// MARK: - Day Cell for Month Grid
struct MonthGridDay: Identifiable, Equatable {
    let id: String
    let dayNumber: Int
    let date: Date?
    let isToday: Bool
    let isCurrentMonth: Bool
}

// MARK: - Month Grid (Right Column of NotchNook Pro)
struct MonthCalendarGridView: View {
    @Binding var selectedDate: Date
    @ObservedObject var calendarManager = CalendarManager.shared

    private let isoCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday is 1st day (M T W T F S S)
        return cal
    }()

    private var daysGrid: [MonthGridDay] {
        let components = isoCalendar.dateComponents([.year, .month], from: selectedDate)
        guard let startOfMonth = isoCalendar.date(from: components),
              let range = isoCalendar.range(of: .day, in: .month, for: startOfMonth) else {
            return []
        }

        let firstWeekday = isoCalendar.component(.weekday, from: startOfMonth)
        // Monday = 2 in standard Gregorian, so offset:
        let leadingSpaces = (firstWeekday - 2 + 7) % 7

        var result: [MonthGridDay] = []
        let today = isoCalendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for i in 0..<leadingSpaces {
            result.append(MonthGridDay(id: "lead-\(i)", dayNumber: 0, date: nil, isToday: false, isCurrentMonth: false))
        }

        for day in 1...range.count {
            if let d = isoCalendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                let isTod = isoCalendar.isDate(d, inSameDayAs: today)
                result.append(MonthGridDay(
                    id: formatter.string(from: d),
                    dayNumber: day,
                    date: d,
                    isToday: isTod,
                    isCurrentMonth: true
                ))
            }
        }
        return result
    }

    private var weekdayLetters: [String] {
        let isRussian = Locale.current.language.languageCode?.identifier == "ru" || Locale.preferredLanguages.first?.hasPrefix("ru") == true
        if isRussian {
            return ["П", "В", "С", "Ч", "П", "С", "В"]
        } else {
            return ["M", "T", "W", "T", "F", "S", "S"]
        }
    }

    private var monthAbbr: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: selectedDate).uppercased()
    }

    var body: some View {
        VStack(spacing: 5) {
            // Header Row: + button, expand button, Month in coral
            HStack(spacing: 6) {
                Spacer()

                // Add Event Button
                Button(action: {
                    if let url = URL(string: "calshow://") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(4)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Add new event in Calendar")

                // Open Calendar App
                Button(action: {
                    if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
                        NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
                    }
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(4)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Open Calendar.app")

                // Month Tag in coral (НОЯБ. / NOV)
                Text(monthAbbr)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.95, green: 0.38, blue: 0.32))
            }

            // Weekday Letters Row: П В С Ч П С В
            HStack(spacing: 0) {
                ForEach(Array(weekdayLetters.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray.opacity(0.8))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            // Days Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(daysGrid) { item in
                    if item.dayNumber == 0 || item.date == nil {
                        Color.clear.frame(height: 20)
                    } else if let date = item.date {
                        let isSelected = isoCalendar.isDate(date, inSameDayAs: selectedDate)
                        let hasEvents = !(calendarManager.eventsByDate[item.id] ?? []).isEmpty

                        Button(action: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                selectedDate = date
                            }
                        }) {
                            VStack(spacing: 1) {
                                ZStack {
                                    if item.isToday {
                                        Circle()
                                            .fill(Color(red: 0.95, green: 0.38, blue: 0.32))
                                            .frame(width: 20, height: 20)
                                    } else if isSelected {
                                        Circle()
                                            .fill(Color.white.opacity(0.20))
                                            .frame(width: 20, height: 20)
                                    }

                                    Text("\(item.dayNumber)")
                                        .font(.system(size: 11, weight: item.isToday || isSelected ? .bold : .medium, design: .rounded))
                                        .foregroundColor(item.isToday ? .white : isSelected ? .white : .white.opacity(0.85))
                                }

                                // Dot under date if events exist
                                if hasEvents {
                                    Circle()
                                        .fill(item.isToday ? Color(red: 0.95, green: 0.38, blue: 0.32) : Color.white.opacity(0.6))
                                        .frame(width: 2.5, height: 2.5)
                                } else {
                                    Color.clear.frame(height: 2.5)
                                }
                            }
                            .frame(height: 21)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
}

// MARK: - Left Column (Agenda with Tinted Floating Cards)
struct AgendaColumnView: View {
    @Binding var selectedDate: Date
    @ObservedObject var calendarManager = CalendarManager.shared

    private var headerDateString: String {
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEE, d MMM"
        return weekdayFormatter.string(from: selectedDate).uppercased()
    }

    private var emptyTitle: String {
        let isRussian = Locale.current.language.languageCode?.identifier == "ru" || Locale.preferredLanguages.first?.hasPrefix("ru") == true
        return isRussian ? "На этот день нет событий" : "No events for this day"
    }

    private var emptySubtitle: String {
        let isRussian = Locale.current.language.languageCode?.identifier == "ru" || Locale.preferredLanguages.first?.hasPrefix("ru") == true
        return isRussian ? "Отдыхайте и наслаждайтесь временем!" : "Enjoy your free time!"
    }

    // Group events for selected day and upcoming days
    private var agendaDays: [(date: Date, header: String, events: [EventModel])] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: selectedDate)
        var groups: [(date: Date, header: String, events: [EventModel])] = []

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let titleFormatter = DateFormatter()
        titleFormatter.dateFormat = "EEE, MMM d"

        // Day 0 (selected date)
        let day0Events = calendarManager.events
        if !day0Events.isEmpty {
            groups.append((date: start, header: "", events: day0Events))
        }

        // Days +1, +2, +3 upcoming
        for i in 1...6 {
            if let nextDate = cal.date(byAdding: .day, value: i, to: start) {
                let key = formatter.string(from: nextDate)
                let dayEvents = calendarManager.eventsByDateString[key] ?? []
                if !dayEvents.isEmpty {
                    groups.append((date: nextDate, header: titleFormatter.string(from: nextDate).uppercased(), events: dayEvents))
                }
            }
        }

        return groups
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header (Coral accent)
            HStack(spacing: 6) {
                Text(headerDateString)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.95, green: 0.38, blue: 0.32))

                Spacer()
            }
            .padding(.horizontal, 2)

            // Scrollable List of Floating Cards
            if agendaDays.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.6))
                    Text(emptyTitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    Text(emptySubtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 125)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(agendaDays.enumerated()), id: \.offset) { _, group in
                            VStack(alignment: .leading, spacing: 4) {
                                if !group.header.isEmpty {
                                    Text(group.header)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.gray.opacity(0.8))
                                        .padding(.top, 2)
                                        .padding(.horizontal, 2)
                                }

                                ForEach(group.events) { event in
                                    NotchNookAgendaCard(event: event)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 4)
                }
                .frame(maxHeight: 125)
            }
        }
    }
}

// MARK: - NotchNook Pro Agenda Card (Floating & Tinted with Join Button)
struct NotchNookAgendaCard: View {
    @Environment(\.openURL) private var openURL
    let event: EventModel

    private var eventColor: Color {
        Color(event.calendar.color)
    }

    private var allDayText: String {
        let isRussian = Locale.current.language.languageCode?.identifier == "ru" || Locale.preferredLanguages.first?.hasPrefix("ru") == true
        return isRussian ? "Весь день" : "All-day"
    }

    var body: some View {
        Button(action: {
            if let url = event.calendarAppURL() {
                openURL(url)
            }
        }) {
            HStack(spacing: 8) {
                // Vertical Accent Bar
                Capsule()
                    .fill(eventColor)
                    .frame(width: 3.5, height: 28)

                // Title and Time
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(eventColor.ensureMinimumBrightness(factor: 0.85))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if event.isAllDay {
                            Text(allDayText)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(eventColor.opacity(0.8))
                        } else {
                            Text("\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
                                .font(.system(size: 10))
                                .foregroundColor(eventColor.opacity(0.8))
                        }
                    }
                }

                Spacer(minLength: 4)

                // 1-Click "Join" Button (Green capsule)
                if let meeting = event.meetingInfo {
                    Button(action: {
                        NSWorkspace.shared.open(meeting.url)
                    }) {
                        Text("Join")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(red: 0.15, green: 0.78, blue: 0.45)))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Join meeting: \(meeting.service.rawValue)")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(eventColor.opacity(0.13))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(eventColor.opacity(0.28), lineWidth: 0.6)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Full 2-Column NotchNook Pro Calendar View
public struct CalendarFullView: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @State private var selectedDate = Date()

    public init() {}

    public var body: some View {
        HStack(alignment: .top, spacing: 18) {
            // Left Column: Agenda with cards
            AgendaColumnView(selectedDate: $selectedDate)
                .frame(maxWidth: .infinity)

            // Right Column: Month Grid
            MonthCalendarGridView(selectedDate: $selectedDate)
                .frame(width: 224)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .onChange(of: selectedDate) { _, newDate in
            Task {
                await calendarManager.updateCurrentDate(newDate)
            }
        }
        .onAppear {
            Task {
                await calendarManager.updateCurrentDate(Date.now)
                selectedDate = Date.now
            }
        }
    }
}

// Compact embedding in Home View (next to Music Player)
struct CalendarView: View {
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @State private var today = Date.now

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                coordinator.currentView = .calendar
            }
        }) {
            AgendaColumnView(selectedDate: $today)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Legacy EventListView kept for compatibility
struct EventListView: View {
    let events: [EventModel]

    static func filteredEvents(events: [EventModel]) -> [EventModel] {
        events.filter { event in
            if event.type.isReminder {
                if case .reminder(let completed) = event.type {
                    return !completed || !Defaults[.hideCompletedReminders]
                }
            }
            if event.isAllDay && Defaults[.hideAllDayEvents] {
                return false
            }
            return true
        }
    }

    var body: some View {
        EmptyView()
    }
}
