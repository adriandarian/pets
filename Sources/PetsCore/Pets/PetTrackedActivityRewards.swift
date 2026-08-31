import Foundation

public struct PetTrackedActivityPeriod: Equatable, Sendable {
    public let id: String
    public let interval: DateInterval

    public init(containing date: Date = Date(), calendar: Calendar = .current) {
        var weeklyCalendar = calendar
        weeklyCalendar.firstWeekday = 2
        let interval = weeklyCalendar.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: date, duration: 7 * 24 * 60 * 60)
        self.interval = interval

        let formatter = DateFormatter()
        formatter.calendar = weeklyCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = weeklyCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        self.id = formatter.string(from: interval.start)
    }
}

public struct PetTrackedActivityIncrement: Equatable, Sendable {
    public let providerID: String
    public let seconds: Int64

    public init(providerID: String, seconds: Int64) {
        self.providerID = providerID
        self.seconds = max(0, seconds)
    }
}

public struct PetTrackedActivityAccumulator: Sendable {
    public static let maximumCreditableGap: TimeInterval = 10

    private var previousObservationDate: Date?
    private var previousActiveProviderIDs: Set<String> = []

    public init() {}

    public mutating func observe(
        sessions: [HarnessSession],
        eligibleProviderIDs: Set<String>,
        at date: Date = Date()
    ) -> [PetTrackedActivityIncrement] {
        let currentActiveProviderIDs = Set<String>(sessions.compactMap { session in
            guard eligibleProviderIDs.contains(session.harnessID),
                  session.status == .busy || session.status == .waiting
            else {
                return nil
            }
            return session.harnessID
        })

        defer {
            previousObservationDate = date
            previousActiveProviderIDs = currentActiveProviderIDs
        }

        guard let previousObservationDate else { return [] }
        let elapsed = date.timeIntervalSince(previousObservationDate)
        guard elapsed >= 1 else { return [] }

        let creditedSeconds = Int64(min(elapsed, Self.maximumCreditableGap).rounded(.down))
        guard creditedSeconds > 0 else { return [] }

        return previousActiveProviderIDs
            .intersection(currentActiveProviderIDs)
            .intersection(eligibleProviderIDs)
            .sorted()
            .map { providerID in
                PetTrackedActivityIncrement(
                    providerID: providerID,
                    seconds: creditedSeconds
                )
            }
    }

    public mutating func reset() {
        previousObservationDate = nil
        previousActiveProviderIDs = []
    }
}
