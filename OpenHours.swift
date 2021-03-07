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


enum Hour: Hashable, CustomStringConvertible {

	case sunrise
	case sunset
	case closed
	case off
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
		if scanner.scanString("closed") != nil {
			return .closed
		}
		if scanner.scanString("off") != nil {
			return .off
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
		case .closed:
			return "closed"
		case .off:
			return "off"
		case let .time(time):
			let hour = time/60
			let minute = time%60
			return String(format: "%02d:%02d", arguments: [hour,minute])
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
					// oops, its the start of a time, not a day
					scanner.currentIndex = loc
					return MonthDay(month: mon, day: nil)
				}
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

	static func scan(scanner:Scanner) -> HourRange?
	{
		if let firstHour = Hour.scan(scanner: scanner) {
			switch firstHour {
			case .closed,
				 .off:
				return HourRange(begin: firstHour, end: firstHour)
			default:
				break
			}
			if scanner.scanString("-") != nil {
				if let lastHour = Hour.scan(scanner: scanner) {
					return HourRange(begin: firstHour, end: lastHour)
				}
				return nil
			}
			return nil
		}
		return nil
	}

	func toString() -> String
	{
		switch begin {
		case .closed,
			 .off:
			return begin.toString()
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
		var set = daySet()
		if set.contains(day) {
			set.remove(day)
		} else {
			set.insert(day)
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

	// Parsing

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

	@Published var list : [MonthDayHours]

	var string: String {
		get { return toString() }
		set { list = OpenHours.parseString(newValue) ?? [] }
	}

	init(fromString text:String) {
		list = OpenHours.parseString(text) ?? []
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

	func toString() -> String {
		return OpeningHours.toString(list:list, delimeter:"; ")
	}

	var description: String {
		return toString()
	}
}
