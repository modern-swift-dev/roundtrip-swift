import Foundation

public extension DateFormatter {

    /// Date formatter for serializing / formatting dates
    /// in http headers like `Last-Modified`
    /// or `If-Modified-Since`
    static let httpHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.shortWeekdaySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        formatter.dateFormat = "E, dd MMM yyyy HH:mm:ss 'GMT'"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .gmt
        return formatter
    }()

}
