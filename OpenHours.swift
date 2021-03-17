//
//  OpenHours.swift
//  OpeningHours (iOS)
//
//  Created by Bryce Cogswell on 3/5/21.
//

import Foundation

protocol ParseElement : Hashable, CustomStringConvertible {
	static func scan(scanner: Scanner) -> Self?
	func toString() -> String
}

extension Scanner {
	func scanWord(_ text:String) -> String? {
		let currentIndex = self.currentIndex
		if let _ = scanString(text) {
			let skipped = self.charactersToBeSkipped
			self.charactersToBeSkipped = nil
			if scanCharacters(from: CharacterSet.letters) == nil {
				self.charactersToBeSkipped = skipped
				return text
			}
			self.charactersToBeSkipped = skipped
			self.currentIndex = currentIndex
		}
		return nil
	}
}

func parseList<T:ParseElement>(scanner:Scanner, delimiter:String) -> [T]?
{
	var list = [T]()
	var commaIndex: String.Index? = nil
	repeat {
		if T.self == HourRange.self,
			let commaIndex = commaIndex
		{
			// hack because grammar is poorly defined
			let currentIndex = scanner.currentIndex
			if scanner.scanInt() == nil {
				// next item isn't a time, so exit out to parse a day
				scanner.currentIndex = commaIndex
				return list
			}
			scanner.currentIndex = currentIndex
		}
		guard let hoursRange = T.scan(scanner:scanner) else { return nil }
		list.append(hoursRange)
		commaIndex = scanner.currentIndex
	} while scanner.scanString(delimiter) != nil
	return list
}

func toString<T:ParseElement>(list: [T], delimeter:String) -> String
{
	return list.reduce("") { result, next in
		return result == "" ? next.toString() : result + delimeter + next.toString()
	}
}

enum Modifier: ParseElement {
	case closed
	case off
	case unknown
	case comment(String)

	static func scan(scanner:Scanner) -> Modifier?
	{
		if scanner.scanWord("closed") != nil {
			return .closed
		}
		if scanner.scanWord("off") != nil {
			return .off
		}
		if scanner.scanWord("unknown") != nil {
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

// "05:30"
enum Hour: ParseElement {

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
		if scanner.scanWord("sunrise") != nil ||
			scanner.scanWord("dawn") != nil {
			return .sunrise
		}
		if scanner.scanWord("sunset") != nil ||
			scanner.scanWord("dusk") != nil {
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

// "Mo"
enum Day: Int, CaseIterable, ParseElement {

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
			if scanner.scanWord(day.toString()) != nil {
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

enum Holiday: ParseElement {
	case PH
	case SH

	static func scan(scanner: Scanner) -> Holiday? {
		if scanner.scanWord("PH") != nil {
			return Holiday.PH
		}
		if scanner.scanWord("SH") != nil {
			return Holiday.SH
		}
		return nil
	}
	func toString() -> String {
		switch self {
		case .PH:	return "PH"
		case .SH:	return "SH"
		}
	}
	var description: String {
		return toString()
	}
}

// "Jan"
enum Month : Int, CaseIterable, ParseElement {
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
			if scanner.scanWord(month.toString()) != nil {
				return month
			}
		}
		return nil

	}
}

// "Jan" or "Jan 5"
struct MonthDay: ParseElement {
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

// "5:30-10:30"
struct HourRange: ParseElement {

	public var begin : Hour
	public var end : Hour
	public var modifier : Modifier?

	static let defaultValue = HourRange(begin: Hour.time(10*60), end: Hour.time(18*60))
	static let allDay = HourRange(begin: Hour.time(0), end: Hour.time(24*60))

	static func scan(scanner:Scanner) -> HourRange?
	{
		if let modifier = Modifier.scan(scanner: scanner) {
			// Sa-Su "closed"
			return HourRange(begin: Hour.time(0), end: Hour.time(0), modifier: modifier)
		}

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
		return "\(begin.toString())-\(end.toString())"
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

// "Mo-Fr"
struct DayRange: ParseElement {
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

// "Apr 5-10" or "Apr 3-May 22"
struct MonthDayRange: ParseElement {
	var begin: MonthDay
	var end: MonthDay

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

// "Mo-Fr 6:00-18:00, Sa,Su 6:00-12:00"
struct DaysHours: ParseElement {

	var days : [DayRange]
	var hours : [HourRange]

	static let everyDay:Set<Int> = [0,1,2,3,4,5,6]

	static func scan(scanner: Scanner) -> DaysHours?
	{
		let days : [DayRange] = parseList(scanner: scanner, delimiter: ",") ?? []
		let hours : [HourRange] = parseList(scanner: scanner, delimiter: ",") ?? []
		if days.count == 0 && hours.count == 0 {
			return nil
		}
		return DaysHours(days: days, hours: hours)
	}

	static let defaultValue = DaysHours(days: [DayRange.defaultValue], hours: [HourRange.defaultValue])
	static let hours_24_7 = DaysHours(days: [], hours: [HourRange.allDay])

	func is24_7() -> Bool {
		if days.count == 0,
		   hours.count == 1,
		   let hourRange = hours.first,
		   hourRange.is24Hour()
		{
			return true
		}
		return false
	}

	mutating func addHoursRange() -> Void {
		hours.append(HourRange.defaultValue)
	}
	mutating func deleteHoursRange(at index:Int) -> Void {
		hours.remove(at: index)
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

	static func dayRangesForDaySet( _ set: Set<Int> ) -> [DayRange] {
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
		return newrange
	}

	mutating func toggleDay(day:Int) -> Void {
		var set = daySet()

		if set.isEmpty {
			set = DaysHours.everyDay
		}
		if set.contains(day) {
			set.remove(day)
		} else {
			set.insert(day)
		}
		if set == DaysHours.everyDay {
			self.days = []
			return
		}
		self.days = DaysHours.dayRangesForDaySet(set)
	}

	func toString() -> String {
		let s1 = OpeningHours.toString(list: days, delimeter: ",")
		let s2 = OpeningHours.toString(list: hours, delimeter: ",")
		return s1.count > 0 && s2.count > 0 ? s1+" "+s2 : s1+s2
	}
	var description: String {
		return toString()
	}
}

// "Jan-Sep M-F 10:00-18:00"
struct MonthsDaysHours: ParseElement {

	var months: [MonthDayRange]
	var daysHours: [DaysHours]

	func is24_7() -> Bool {
		if months.count == 0,
		   daysHours.count == 1,
		   daysHours.first!.is24_7()
		{
			return true
		}
		return false
	}

	func definedDays() -> Set<Int> {
		return daysHours.reduce(Set<Int>()) { result, dayHours in
			return result.union(dayHours.daySet())
		}
	}

	mutating func addMonthDayRange() -> Void {
		months.append(MonthDayRange.defaultValue)
	}
	mutating func deleteMonthDayRange(at index:Int) -> Void {
		months.remove(at: index)
	}
	mutating func addDaysHours() -> Void {
		let days = definedDays()
		var dh = DaysHours.defaultValue
		if days.count > 0 {
			let set = DaysHours.everyDay.subtracting(days)
			dh.days = DaysHours.dayRangesForDaySet( set )
		}
		daysHours.append(dh)
	}
	mutating func deleteDaysHours(at index:Int) -> Void {
		daysHours.remove(at: index)
	}

	func toString() -> String {
		if is24_7() {
			return "24/7"
		}
		let s1 = OpeningHours.toString(list: months, delimeter: ",")
		let s2 = OpeningHours.toString(list: daysHours, delimeter: ", ")
		let r = s1.count > 0 && s2.count > 0 ? s1+" "+s2 : s1+s2
		return r
	}

	var description: String {
		return toString()
	}

	static func scan(scanner:Scanner) -> MonthsDaysHours?
	{
		let months : [MonthDayRange] = parseList(scanner: scanner, delimiter: ",") ?? []
		let daysHours : [DaysHours] = parseList(scanner: scanner, delimiter: ",") ?? []
		if months.count == 0 && daysHours.count == 0 {
			return nil
		}
		return MonthsDaysHours(months: months, daysHours: daysHours)
	}
}

class OpenHours: ObservableObject, CustomStringConvertible {

	@Published var groups : [MonthsDaysHours]
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

	static func parseString(_ text:String) -> [MonthsDaysHours]? {
		let scanner = Scanner(string: text)
		scanner.caseSensitive = false
		scanner.charactersToBeSkipped = CharacterSet.whitespaces

		if scanner.scanString("24/7") != nil {
			if scanner.isAtEnd {
				return [MonthsDaysHours(months: [], daysHours: [DaysHours.hours_24_7])]
			}
		}
		guard let result : [MonthsDaysHours] = parseList(scanner: scanner, delimiter: ";") else { return nil }
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
		groups.append(MonthsDaysHours(months: [],
									daysHours: [DaysHours(days: [DayRange.defaultValue],
														  hours: [HourRange.defaultValue])]))
	}


	func toString() -> String {
		return OpeningHours.toString(list:groups, delimeter:"; ")
	}

	var description: String {
		return toString()
	}
}
