//
//  EventModel.swift
//  Calendr
//
//  Created by Paker on 24/12/20.
//  Original source: https://github.com/pakerwreah/Calendr
//  Modified by Alexander on 2025-05-18.
//

import Foundation
import AppKit

enum MeetingService: String, Equatable {
    case zoom = "Zoom"
    case googleMeet = "Google Meet"
    case teams = "Teams"
    case webex = "Webex"
    case generic = "Meeting"

    var icon: String {
        switch self {
        case .zoom, .webex, .generic: return "video.fill"
        case .googleMeet: return "video.badge.plus"
        case .teams: return "person.2.fill"
        }
    }

    var brandColor: NSColor {
        switch self {
        case .zoom: return NSColor(red: 0.18, green: 0.54, blue: 0.98, alpha: 1.0)
        case .googleMeet: return NSColor(red: 0.0, green: 0.65, blue: 0.42, alpha: 1.0)
        case .teams: return NSColor(red: 0.38, green: 0.42, blue: 0.88, alpha: 1.0)
        case .webex: return NSColor(red: 0.0, green: 0.75, blue: 0.85, alpha: 1.0)
        case .generic: return NSColor.systemBlue
        }
    }
}

struct EventModel: Equatable, Identifiable {
    let id: String
    let start: Date
    let end: Date
    let title: String
    let location: String?
    let notes: String?
    let url: URL?
    let isAllDay: Bool
    let type: EventType
    let calendar: CalendarModel
    let participants: [Participant]
    let timeZone: TimeZone?
    let hasRecurrenceRules: Bool
    let priority: Priority?
}

enum AttendanceStatus: Comparable {
    case accepted
    case maybe
    case pending
    case declined
    case unknown

    private var comparisonValue: Int {
        switch self {
        case .accepted: return 1
        case .maybe: return 2
        case .declined: return 3
        case .pending: return 4
        case .unknown: return 5
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.comparisonValue < rhs.comparisonValue
    }
}

enum EventType: Equatable {
    case event(AttendanceStatus)
    case birthday
    case reminder(completed: Bool)
}

enum EventStatus: Equatable {
    case upcoming
    case inProgress
    case ended
}

extension EventType {
    var isEvent: Bool { if case .event = self { return true } else { return false } }
    var isBirthday: Bool { self ~= .birthday }
    var isReminder: Bool { if case .reminder = self { return true } else { return false } }
}

extension EventModel {
    
    var eventStatus: EventStatus {
        if start > Date() {
            return .upcoming
        } else if end > Date() {
            return .inProgress
        } else {
            return .ended
        }
    }
        
    var attendance: AttendanceStatus { if case .event(let attendance) = type { return attendance } else { return .unknown } }

    var isMeeting: Bool { !participants.isEmpty }

    var meetingInfo: (service: MeetingService, url: URL)? {
        let text = "\(location ?? "") \(notes ?? "") \(url?.absoluteString ?? "")"

        if let match = text.range(of: "https://[a-zA-Z0-9.-]*zoom.us/j/[a-zA-Z0-9?&=_-]+", options: .regularExpression),
           let url = URL(string: String(text[match])) {
            return (.zoom, url)
        }
        if let match = text.range(of: "https://meet.google.com/[a-z]{3}-[a-z]{4}-[a-z]{3}", options: .regularExpression),
           let url = URL(string: String(text[match])) {
            return (.googleMeet, url)
        }
        if let match = text.range(of: "https://teams.microsoft.com/l/meetup-join/[a-zA-Z0-9%?&=_/-]+", options: .regularExpression),
           let url = URL(string: String(text[match])) {
            return (.teams, url)
        }
        if let match = text.range(of: "https://[a-zA-Z0-9.-]*webex.com/[a-zA-Z0-9?&=_/.-]+", options: .regularExpression),
           let url = URL(string: String(text[match])) {
            return (.webex, url)
        }
        if let u = url, let host = u.host?.lowercased() {
            if host.contains("zoom.us") { return (.zoom, u) }
            if host.contains("meet.google.com") { return (.googleMeet, u) }
            if host.contains("teams.microsoft.com") { return (.teams, u) }
        }
        return nil
    }

    func calendarAppURL() -> URL? {

        guard let id = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }

        guard !type.isReminder else {
            return URL(string: "x-apple-reminderkit://remcdreminder/\(id)")
        }

        let date: String
        if hasRecurrenceRules {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if !isAllDay {
                formatter.timeZone = .init(secondsFromGMT: 0)
            }
            if let formattedDate = formatter.string(for: start) {
                date = "/\(formattedDate)"
            } else {
                return nil
            }
        } else {
            date =  ""
        }
        return URL(string: "ical://ekevent\(date)/\(id)?method=show&options=more")
    }
}

struct Participant: Hashable {
    let name: String
    let status: AttendanceStatus
    let isOrganizer: Bool
    let isCurrentUser: Bool
}

enum Priority {
    case high
    case medium
    case low
}
