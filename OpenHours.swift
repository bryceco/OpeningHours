//
//  OpenHours.swift
//  OpeningHours (iOS)
//
//  Created by Bryce Cogswell on 3/5/21.
//

import Foundation

protocol Scannable {
	static func scan(scanner: Scanner) -> Self?
}
protocol Stringable {
	func toString() -> String
}

func parseList<T:Scannable>(scanner:Scanner, delimiter:String) -> [T]?
{
	var list = [T]()
	repeat {
		guard let hoursRange = T.scan(scanner:scanner) else { return nil }
		list.append(hoursRange)
	} while scanner.scanString(delimiter) != nil
	return list
}

func toString<T:Stringable>(list: [T], delimeter:String) -> String
{
	var s = ""
	for entry in list {
		if s.count > 0 {
			s += delimeter
		}
		s += entry.toString()
	}
	return s
}

enum Modifier: Hashable, CustomStringConvertible {
	case closed
	case off
	case unknown
	case comment(String)

	static func scan(scanner:Scanner) -> Modifier?
	{
		if scanner.scanString("closed") != nil {
			return .closed
		}
		if scanner.scanString("off") != nil {
			return .off
		}
		if scanner.scanString("unknown") != nil {
			return .unknown
		}
		let index = scanner.currentIndex
		if scanner.scanString("\"") != nil {
			if let s = scanner.scanUpToString("\"") {
				_ = scanner.scanString("\"")
				return .comment(s)
			}
			scanner.currentIndex = index
		}
		return nil
	}

	func toString() -> String
	{
		switch self {
		case .closed:
			return "closed"
		case .off:
			return "off"
		case .unknown:
			return "unknown"
		case let .comment(text):
			return "\"\(text)\""
		}
	}

	var description: String {
		return toString()
	}
}

enum Hour: Hashable, CustomStringConvertible {

	case sunrise
	case sunset
	case time(Int)

	static func scan(scanner:Scanner) -> Hour?
	{
		if let hour = scanner.scanInt(),
			scanner.scanString(":") != nil,
			let minute = scanner.scanInt()
		{
			return .time(hour*60+minute)
		}
		if scanner.scanString("sunrise") != nil ||
			scanner.scanString("dawn") != nil {
			return .sunrise
		}
		if scanner.scanString("sunset") != nil ||
			scanner.scanString("dusk") != nil {
			return .sunset
		}
		return nil
	}

	func toString() -> String
	{
		switch self {
		case .sunrise:
			return "sunrise"
		case .sunset:
			return "sunset"
		case let .time(time):
			let hour = time/60
			let minute = time%60
			return String(format: "%02d:%02d", arguments: [hour,minute])
		}
	}

	var asDate: Date {
		get {
			switch self {
			case let .time(time):
				let gregorian = Calendar(identifier: .gregorian)
				var components = gregorian.dateComponents([.year,.month,.day],
														  from: Date())
				components.hour = time / 60
				components.minute = time % 60
				components.second = 0
				let yourDate = gregorian.date(from: components)
				return yourDate!
			default:
				return Date()
			}
		}
		set {
			let gregorian = Calendar(identifier: .gregorian)
			let components = gregorian.dateComponents([.hour,.minute], from: newValue)
			self = .time(components.hour!*60 + components.minute!)
		}
	}

	var description: String {
		return toString()
	}

	func toMinute() -> Int?
	{
		switch self {
		case let .time(time):
			return time
		default:
			return nil
		}
	}
}

enum Day: Int, CaseIterable {

	case Mo
	case Tu
	case We
	case Th
	case Fr
	case Sa
	case Su
	case PH
	case SH

	static func scan(scanner:Scanner) -> Day?
	{
		for day in Day.allCases {
			if scanner.scanString(day.toString()) != nil {
				return day
			}
		}
		return nil
	}

	func toString() -> String {
		switch self {
		case .Mo: return "Mo"
		case .Tu: return "Tu"
		case .We: return "We"
		case .Th: return "Th"
		case .Fr: return "Fr"
		case .Sa: return "Sa"
		case .Su: return "Su"
		case .PH: return "PH"
		case .SH: return "SH"
		}
	}

	var description: String {
		return toString()
	}
}

enum Month : Int, CaseIterable, CustomStringConvertible {
	case Jan
	case Feb
	case Mar
	case Apr
	case May
	case Jun
	case Jul
	case Aug
	case Sep
	case Oct
	case Nov
	case Dec

	public static let names = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

	func toString() -> String {
		return Month.names[self.rawValue]
	}

	var description: String {
		return toString()
	}

	static func scan(scanner:Scanner) -> Month?
	{
		for month in Month.allCases {
			if scanner.scanString(month.toString()) != nil {
				return month
			}
		}
		return nil

	}
}

struct MonthDay: Hashable, CustomStringConvertible {
	var month: Month
	var day: Int?

	static func scan(scanner:Scanner) -> MonthDay?
	{
		if let mon = Month.scan(scanner: scanner) {
			let loc = scanner.currentIndex
			if let day = scanner.scanInt() {
				if scanner.scanString(":") != nil {
					// "Apr 5:30-6:30"
					scanner.currentIndex = loc
					return MonthDay(month: mon, day: nil)
				}
				// "Apr 5"
				return MonthDay(month: mon, day: day)
			} else {
				return MonthDay(month: mon, day: nil)
			}
		}
		return nil
	}

	func toString() -> String {
		if let day = day {
			return "\(month.toString()) \(day)"
		} else {
			return month.toString()
		}
	}

	var description: String {
		return toString()
	}
}

struct HourRange: Scannable, Stringable, Hashable, CustomStringConvertible {

	public var begin : Hour
	public var end : Hour
	public var modifier : Modifier?

	static let defaultValue = HourRange(begin: Hour.time(10*60), end: Hour.time(18*60))

	static func scan(scanner:Scanner) -> HourRange?
	{
		let index = scanner.currentIndex
		if let firstHour = Hour.scan(scanner: scanner),
		   scanner.scanString("-") != nil,
		   let lastHour = Hour.scan(scanner: scanner)
		{
			let modifier = Modifier.scan(scanner: scanner)
			return HourRange(begin: firstHour, end: lastHour, modifier: modifier)
		}
		scanner.currentIndex = index
		return nil
	}

	func toString() -> String
	{
		switch begin {
		default:
			return "\(begin.toString())-\(end.toString())"
		}
	}

	var description: String {
		return toString()
	}

	func is24Hour() -> Bool {
		if let begin = begin.toMinute(),
		   begin == 0,
		   let end = end.toMinute(),
		   end == 24*60
		{
			return true
		}
		return false
	}
}

struct DayRange: Scannable, Stringable, Hashable, CustomStringConvertible {
	var begin: Day
	var end: Day

	static let defaultValue = DayRange(begin: .Mo, end: .Su)

	static func scan(scanner:Scanner) -> DayRange?
	{
		if let firstDay = Day.scan(scanner: scanner) {
			if scanner.scanString("-") != nil {
				if let lastDay = Day.scan(scanner: scanner) {
					return DayRange(begin: firstDay, end: lastDay)
				}
				return nil
			}
			return DayRange(begin: firstDay, end: firstDay)
		}
		return nil
	}

	func toString() -> String {
		if begin == end {
			return "\(begin)"
		} else {
			return "\(begin)-\(end)"
		}
	}
	var description: String {
		return self.toString()
	}
}

struct MonthDayRange: Scannable, Stringable, Hashable, CustomStringConvertible {
	var begin: MonthDay
	var end: MonthDay
	let id = UUID()

	static let defaultValue = MonthDayRange(begin: MonthDay(month: .Jan, day: nil), end: MonthDay(month: .Dec, day: nil))

	static func scan(scanner: Scanner) -> MonthDayRange?
	{
		if let first = MonthDay.scan(scanner: scanner) {
			if scanner.scanString("-") != nil {
				if first.day != nil,
				   let day = scanner.scanInt()
				{
					// "Apr 5-10"
					let last = MonthDay(month: first.month, day: day)
					return MonthDayRange(begin: first, end: last)
				}
				// "Apr 5-May 10"
				if let last = MonthDay.scan(scanner: scanner) {
					return MonthDayRange(begin: first, end: last)
				}
				return nil
			}
			return MonthDayRange(begin: first, end: first)
		}
		return nil
	}

	func toString() -> String {
		if begin == end {
			return "\(begin)"
		} else {
			return "\(begin)-\(end)"
		}
	}

	var description: String {
		return toString()
	}
}

struct MonthDayHours: Scannable, Stringable, Hashable, CustomStringConvertible {

	var months: [MonthDayRange]
	var days : [DayRange]
	var hours : [HourRange]

	func is24_7() -> Bool {
		if months.count == 0,
		   days.count == 0,
		   hours.count == 1,
		   let hourRange = hours.first,
		   hourRange.is24Hour()
		{
			return true
		}
		return false
	}

	func daySet() -> Set<Int> {
		var set = Set<Int>()
		for dayRange in days {
			for day in dayRange.begin.rawValue...dayRange.end.rawValue {
				set.insert(day)
			}
		}
		return set
	}

	mutating func toggleDay(day:Int) -> Void {
		let everyDay:Set<Int> = [0,1,2,3,4,5,6]
		var set = daySet()

		if set.isEmpty {
			set = everyDay
		}
		if set.contains(day) {
			set.remove(day)
		} else {
			set.insert(day)
		}
		if set == everyDay {
			self.days = []
			return
		}
		var newrange = [DayRange]()
		for d in 0..<7 {
			if set.contains(d) {
				let day = Day(rawValue: d)!
				if newrange.last?.end.rawValue == d-1 {
					// extends last range
					newrange[newrange.count-1].end = day
				} else {
					// start a new range
					newrange.append(DayRange(begin: day, end: day))
				}
			}
		}
		self.days = newrange
	}
	mutating func deleteMonthDayRange(at index:Int) -> Void {
		months.remove(at: index)
	}
	mutating func deleteHoursRange(at index:Int) -> Void {
		hours.remove(at: index)
	}
	mutating func addMonthDayRange() -> Void {
		months.append(MonthDayRange.defaultValue)
	}
	mutating func addHoursRange() -> Void {
		hours.append(HourRange.defaultValue)
	}


	func toString() -> String {
		if is24_7() {
			return "24/7"
		}
		let s1 = OpeningHours.toString(list: months, delimeter: ",")
		let s2 = OpeningHours.toString(list: days, delimeter: ",")
		let s3 = OpeningHours.toString(list: hours, delimeter: ",")
		var r = ""
		for s in [s1, s2, s3] {
			if s.count > 0 {
				if r.count > 0 {
					r += " "
				}
				r += s
			}
		}
		return r
	}

	var description: String {
		return toString()
	}

	static func scan(scanner:Scanner) -> MonthDayHours?
	{
		let months : [MonthDayRange] = parseList(scanner: scanner, delimiter: ",") ?? []
		let days : [DayRange] = parseList(scanner: scanner, delimiter: ",") ?? []
		let hours : [HourRange] = parseList(scanner: scanner, delimiter: ",") ?? []
		if months.count == 0 && days.count == 0 && hours.count == 0 {
			return nil
		}
		return MonthDayHours(months: months, days: days, hours: hours)
	}
}

class OpenHours: ObservableObject, CustomStringConvertible {

	@Published var groups : [MonthDayHours]
	private var textual : String

	var string: String {
		get {
			if groups.count > 0 {
				textual = toString()
			}
			return textual
		}
		set {
			if let result = OpenHours.parseString(newValue) {
				groups = result
				textual = toString()
			} else {
				textual = newValue
			}
		}
	}

	init(fromString text:String) {
		textual = text
		groups = OpenHours.parseString(text) ?? []
	}

	static func parseString(_ text:String) -> [MonthDayHours]? {
		let scanner = Scanner(string: text)
		scanner.caseSensitive = true
		scanner.charactersToBeSkipped = CharacterSet.whitespaces

		if scanner.scanString("24/7") != nil {
			if scanner.isAtEnd {
				return [MonthDayHours(months: [],
									  days: [],
									  hours: [HourRange(begin: Hour.time(0), end: Hour.time(24*60))])]
			}
		}
		guard let result : [MonthDayHours] = parseList(scanner: scanner, delimiter: ";") else { return nil }
		if !scanner.isAtEnd {
			return nil
		}
		return result
	}

	func deleteMonthDayHours(at index:Int) -> Void {
		groups.remove(at: index)
		if groups.count == 0 {
			textual = ""
		}
	}
	func addMonthDayHours() -> Void {
		groups.append(MonthDayHours(months: [], days: [DayRange.defaultValue], hours: [HourRange.defaultValue]))
	}


	func toString() -> String {
		return OpeningHours.toString(list:groups, delimeter:"; ")
	}

	var description: String {
		return toString()
	}
}
