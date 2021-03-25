//
//  OpenHours.swift
//  OpeningHours (iOS)
//
//  Created by Bryce Cogswell on 3/5/21.
//

import Foundation

protocol ParseElement : Hashable, CustomStringConvertible, CustomDebugStringConvertible {
	static func scan(scanner: Scanner) -> Self?
	func toString() -> String
}

extension ParseElement {
	var description: String {
		return toString()
	}
	var debugDescription: String {
		return toString()
	}
}

extension Scanner {
	func scanWord(_ text:String) -> String? {
		let index = self.currentIndex
		if let _ = scanString(text) {
			let skipped = self.charactersToBeSkipped
			self.charactersToBeSkipped = nil
			if scanCharacters(from: CharacterSet.letters) == nil {
				self.charactersToBeSkipped = skipped
				return text
			}
			self.charactersToBeSkipped = skipped
			self.currentIndex = index
		}
		return nil
	}

	func scanAnyWord(_ list:[String]) -> String? {
		for word in list {
			if let text = scanWord(word) {
				return text
			}
		}
		return nil
	}

	func scanWordPrefix(_ text:String, minLength:Int) -> String? {
		let index = self.currentIndex

		if let s = scanCharacters(from: CharacterSet.letters),
		   s.count >= minLength,
		   // s.compare(text, options: .caseInsensitive, range: s.startIndex..<s.endIndex) == .orderedSame
		   text.lowercased().hasPrefix(s.lowercased())
		{
			return s
		}
		self.currentIndex = index
		return nil
	}

	static let dashCharacters = CharacterSet.init(charactersIn: "-–‐‒–—―~～") // - %u2013 %u2010 %u2012 %u2013 %u2014 %u2015
	func scanDash() -> String? {
		if let dash = self.scanCharacters(from: Scanner.dashCharacters) {
			// could end up with several dashes in a row but that shouldn't hurt anything
			return dash
		}
		if let dash = self.scanWord("to") {
			return dash
		}
		return nil
	}

	var remainder: String {
		let index = self.currentIndex
		let s = scanUpToString("***")
		self.currentIndex = index
		return s ?? ""
	}
}

// parses "T-T"
class Util {
	static func parseRange<T>(scanner:Scanner, scan:(Scanner)->T? ) -> (T,T)? {
		if let first = scan(scanner) {
			let index = scanner.currentIndex
			if scanner.scanDash() != nil {
				if let second = scan(scanner) {
					return (first,second)
				}
				scanner.currentIndex = index
			}
			return (first,first)
		}
		return nil
	}

	// parses "T,T,T"
	static func parseList<T>(scanner:Scanner, scan:(Scanner)->T?, delimiter:String) -> [T]?
	{
		var list = [T]()
		var delimiterIndex: String.Index? = nil
		repeat {
			guard let item = scan(scanner) else {
				// back up to before preceding comma
				if let delimiterIndex = delimiterIndex {
					scanner.currentIndex = delimiterIndex
					return list
				} else {
					return nil
				}
			}
			list.append(item)
			delimiterIndex = scanner.currentIndex
		} while scanner.scanString(delimiter) != nil
		return list
	}

	// parses "T-T,T,T-T"
	static func parseListRange<T>(scanner: Scanner, scan:(Scanner)->T?, delimiter:String) -> [(T,T)]? {
		return parseList(scanner: scanner,
						 scan: { scanner in	return parseRange(scanner: scanner, scan: scan) },
						 delimiter: delimiter)
	}

	static func stringListToString(list: [String?], delimeter:String) -> String
	{
		return list.reduce("") { result, next in
			if let next = next,
			   next.count > 0
			{
				return result == "" ? next : result + delimeter + next
			} else {
				return result
			}
		}
	}
	static func elementListToString<T:ParseElement>(list: [T], delimeter:String) -> String
	{
		return list.reduce("") { result, next in
			return result == "" ? next.toString() : result + delimeter + next.toString()
		}
	}
}

struct Comment: ParseElement {
	var text: String
	static func scan(scanner: Scanner) -> Comment? {
		let index = scanner.currentIndex
		if scanner.scanString("\"") != nil {
			if let s = scanner.scanUpToString("\"") {
				_ = scanner.scanString("\"")
				return Comment(text: s)
			}
			scanner.currentIndex = index
		}
		return nil
	}
	func toString() -> String {
		return "\"\(text)\""
	}
}

enum Modifier: String, CaseIterable, ParseElement {
	case open = "open"
	case closed = "closed"
	case off = "off"
	case unknown = "unknown"

	static func scan(scanner:Scanner) -> Modifier?
	{
		for value in Modifier.allCases {
			if scanner.scanWord(value.rawValue) != nil {
				return value
			}
		}
		return nil
	}

	func toString() -> String
	{
		return self.rawValue
	}
}

// "05:30"
enum Hour: CaseIterable, ParseElement {
	// items with a possible offset:
	case sunrise(Int)
	case sunset(Int)
	case dawn(Int)
	case dusk(Int)
	// a regular time like 12:50, expressed in minutes:
	case time(Int)
	// undefined
	case none			// used when trailing time of a range is missing

	// time must be first here:
	static var allCases: [Hour] = [.time(0),.sunrise(0),.sunset(0),.dawn(0),.dusk(0),.none]

	func toMinute() -> Int?
	{
		switch self {
		case let .time(time):
			return time
		default:
			return nil
		}
	}
	func isTime() -> Bool {
		return toMinute() != nil
	}

	static let AMs = ["AM","A.M."]
	static let PMs = ["PM","P.M."]
	static let minuteSeparators = CharacterSet(charactersIn: ":_.")

	static func scan(scanner:Scanner) -> Hour?
	{
		let index = scanner.currentIndex
		let skipped = scanner.charactersToBeSkipped
		defer { scanner.charactersToBeSkipped = skipped }
		scanner.charactersToBeSkipped = nil
		_ = scanner.scanCharacters(from: CharacterSet.whitespacesAndNewlines)

		// 12:00 etc.
		if let hour = scanner.scanInt(),
		   hour >= 0 && hour <= 24
		{
			let index2 = scanner.currentIndex
			if scanner.scanCharacters(from: minuteSeparators)?.count == 1,
			   let minute = scanner.scanInt(),
			   minute >= 0 && minute < 60
			{
				// "10:25"
				scanner.charactersToBeSkipped = skipped
				if scanner.scanAnyWord(AMs) != nil {
					return .time((hour%12)*60+minute)
				}
				if scanner.scanAnyWord(PMs) != nil {
					return .time((12+hour%12)*60+minute)
				}
				return .time(hour*60+minute)
			}

			// 10PM
			scanner.charactersToBeSkipped = skipped
			scanner.currentIndex = index2
			if scanner.scanAnyWord(AMs) != nil {
				return .time((hour%12)*60)
			}
			if scanner.scanAnyWord(PMs) != nil {
				return .time((12+(hour%12))*60)
			}
		}
		scanner.currentIndex = index
		scanner.charactersToBeSkipped = skipped

		// named times
		if let event = scanEvent(scanner: scanner) {
			return event
		}
		// (sunrise-1:00)
		if scanner.scanString("(") != nil,
		   let event = scanEvent(scanner: scanner),
		   let sign = scanner.scanCharacters(from: CharacterSet.init(charactersIn: "+-")),
		   sign.count == 1,
		   let offset = Hour.scan(scanner: scanner),
		   let minutes = offset.toMinute(),
		   scanner.scanString(")") != nil
		{
			return event.withOffset(offset: sign == "-" ? -minutes : minutes)
		}
		scanner.currentIndex = index
		return nil
	}

	static func scanEvent(scanner:Scanner) -> Self? {
		if scanner.scanString("sunrise") != nil	{ return .sunrise(0) }
		if scanner.scanString("sunset") != nil	{ return .sunset(0) }
		if scanner.scanString("dawn") != nil	{ return .dawn(0) }
		if scanner.scanString("dusk") != nil	{ return .dusk(0) }
		return nil
	}

	static func withString(_ text:String, offset:Int) -> Self? {
		switch text.lowercased() {
		case "sunrise":
			return .sunrise(offset)
		case "sunset":
			return .sunset(offset)
		case "dawn":
			return .dawn(offset)
		case "dusk":
			return .dusk(offset)
		default:
			return nil
		}
	}

	func withOffset(offset:Int) -> Self? {
		switch self {
			case .sunrise:		return .sunrise(offset)
			case .sunset:		return .sunset(offset)
			case .dawn:			return .dawn(offset)
			case .dusk:			return .dusk(offset)
			default:			return self
		}
	}

	func toString() -> String
	{
		var name: String
		var offset: Int

		switch self {
		case let .sunrise(off):
			name = "sunrise"
			offset = off
		case let .sunset(off):
			name = "sunset"
			offset = off
		case let .dawn(off):
			name = "dawn"
			offset = off
		case let .dusk(off):
			name = "dusk"
			offset = off
		case .none:
			return "none"
		case let .time(time):
			let hour = time/60
			let minute = time%60
			return String(format: "%02d:%02d", arguments: [hour,minute])
		}
		if offset == 0 {
			return name
		} else {
			let sign = offset >= 0 ? "+" : "-"
			let hour = Hour.time(abs(offset))
			return "(\(name)\(sign)\(hour.toString()))"
		}
	}

	var hourBinding: Int {
		get {
			switch self {
			case let .time(time):	return time / 60
			default:				return 0
			}
		}
		set {
			var minute = 0
			switch self {
			case let .time(time):	minute = time % 60
			default:				break
			}
			self = .time(newValue*60 + minute)
		}
	}

	var minuteBinding: Int {
		get {
			switch self {
			case let .time(time):	return time % 60 / 5
			default:				return 0
			}
		}
		set {
			var hour = 0
			switch self {
			case let .time(time):	hour = time / 60
			default:				break
			}
			self = .time(hour*60 + newValue*5)
		}
	}

	var typeBinding: Int {
		get {
			switch self {
			case .time:
				return 0
			default:
				return Hour.allCases.firstIndex(of: self)!
			}
		}
		set {
			self = Hour.allCases[newValue]
		}
	}
}

// "Mo"
enum Weekday: Int, CaseIterable, ParseElement {

	case Mo
	case Tu
	case We
	case Th
	case Fr
	case Sa
	case Su

	static let synonyms = [
		["Monday"],
		["Tuesday"],
		["Wednesday"],
		["Thursday"],
		["Friday"],
		["Saturday"],
		["Sunday"]
	]

	static func scan(scanner:Scanner) -> Weekday?
	{
		for day in synonyms.indices {
			for text in synonyms[day] {
				if scanner.scanWordPrefix(text, minLength: 2) != nil {
					return Weekday(rawValue: day)
				}
			}
		}
		return nil
	}

	func toString() -> String {
		return String(Weekday.synonyms[self.rawValue][0].prefix(2))
	}
}

enum PublicHoliday: String, CaseIterable, ParseElement {
	case PH = "PH"
	case SH = "SH"

	static func scan(scanner: Scanner) -> PublicHoliday? {
		for value in PublicHoliday.allCases {
			if scanner.scanWord(value.rawValue) != nil {
				return value
			}
		}
		return nil
	}
	func toString() -> String {
		return self.rawValue
	}
}

// "We[-1]"
struct NthWeekday: ParseElement {
	var weekday: Weekday
	var nth: NthEntry

	static func scan(scanner: Scanner) -> NthWeekday? {
		let index = scanner.currentIndex
		if let day = Weekday.scan(scanner: scanner),
		   let nthList = NthEntryList.scan(scanner: scanner),
		   nthList.list.count == 1,
		   let nth = nthList.list.first,
		   nth.begin == nth.end
		{
			return NthWeekday(weekday: day, nth: nth)
		}
		scanner.currentIndex = index
		return nil
	}

	func toString() -> String {
		return "\(weekday.toString())[\(nth.toString())]"
	}
}

// "23"
struct Day : ParseElement {
	var rawValue : Int

	static let allCases = Array(1...31).map({Day($0)!})

	init?(_ d:Int) {
		if d < 1 || d > 31 {
			return nil
		}
		self.rawValue = d
	}

	static func scan(scanner: Scanner) -> Day? {
		let index = scanner.currentIndex
		if let d = scanner.scanInt(),
		   let day = Day(d)
		{
			return day
		}
		scanner.currentIndex = index
		return nil
	}

	func toString() -> String {
		return "\(self.rawValue)"
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

struct Year: ParseElement, Hashable, Equatable {
	var rawValue: Int

	static func scan(scanner: Scanner) -> Year? {
		let index = scanner.currentIndex
		if let year = scanner.scanInt(),
		   year >= 1900
		{
			return Year(rawValue: year)
		}
		scanner.currentIndex = index
		return nil
	}

	func toString() -> String {
		return "\(self.rawValue)"
	}
}

enum HolidayName: String, CaseIterable {
	case easter = "easter"
	case thanksgiving = "thanksgiving"
}

struct HolidayDate: ParseElement {
	var year: Year?
	var holiday: HolidayName
	var offset: DayOffset?

	static func scan(scanner: Scanner) -> HolidayDate? {
		for date in HolidayName.allCases {
			if scanner.scanWord(date.rawValue) != nil {
				_ = scanner.scanWord("day")	// "thanksgiving day"
				let offset = DayOffset.scan(scanner: scanner)
				return HolidayDate(holiday: date, offset: offset)
			}
		}
		return nil
	}

	func toString() -> String {
		let a = [year?.toString(), self.holiday.rawValue, offset?.toString() ]
		return Util.stringListToString(list: a, delimeter: " ")
	}
}

// "Jan" or "Jan 5" or "Jan Su[-1]"
struct MonthDate: ParseElement {
	var year: Year?
	var month: Month
	var day: Day?					// day and nthWeekday are mutually exclusive
	var nthWeekday: NthWeekday?

	static func scan(scanner:Scanner) -> MonthDate?
	{
		let index = scanner.currentIndex
		let year = Year.scan(scanner: scanner)
		if let mon = Month.scan(scanner: scanner) {
			let index2 = scanner.currentIndex
			if nextTokenCouldBeHour(scanner: scanner) {
				// "Apr 5:30-6:30"
				scanner.currentIndex = index2
				return MonthDate(year: year, month: mon, day: nil)
			}
			if let day = Day.scan(scanner: scanner) {
				// "Apr 5"
				return MonthDate(year: year, month: mon, day: day)
			}
			if let nthWeekday = NthWeekday.scan(scanner: scanner) {
				// "Apr Fri[-1]"
				return MonthDate(year: year, month: mon, day: nil, nthWeekday: nthWeekday)
			}
			return MonthDate(year: year, month: mon, day: nil)
		}
		scanner.currentIndex = index
		return nil
	}

	func toString() -> String {
		let d = day?.toString() ?? nthWeekday?.toString() ?? nil
		let a = [year?.toString(), month.toString(), d]
		return Util.stringListToString(list: a, delimeter: " ")
	}

	static func nextTokenCouldBeHour(scanner:Scanner) -> Bool {
		let start = scanner.currentIndex
		defer { scanner.currentIndex = start }
		guard let range = HourRange.scan(scanner: scanner) else { return false }	// can't parse as hour
		if range.begin.toMinute() == nil || range.end.toMinute() == nil { return true }	// it's sunrise, or 12-sunset, etc.
		let sub = scanner.string[start..<scanner.currentIndex]
		if sub.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) != nil {
			return true	// contains a non-digit, so it isn't a plain integer
		}
		guard let num = Int(sub) else { return false }
		return num >= 0 && num <= 24
	}
}

enum DayOfYear: ParseElement {
	case monthDate(MonthDate)
	case holidayDate(HolidayDate)

	static func scan(scanner: Scanner) -> DayOfYear? {
		if let mon = MonthDate.scan(scanner: scanner) {
			return DayOfYear.monthDate(mon)
		}
		if let holiday = HolidayDate.scan(scanner: scanner) {
			return DayOfYear.holidayDate(holiday)
		}
		return nil
	}

	func toString() -> String {
		switch self {
		case let .monthDate(mon):
			return mon.toString()
		case let .holidayDate(hol):
			return hol.toString()
		}
	}

	static let allTypes = ["Date","Holiday"]
	var typeBinding: Int {
		get {
			switch self {
			case .monthDate:
				return 0
			case .holidayDate:
				return 1
			}
		}
		set {
			switch self {
			case .monthDate:
				switch newValue {
				case 1:
					self = .holidayDate(HolidayDate(year: nil, holiday: .easter))
				default:
					break
				}
			case .holidayDate:
				switch newValue {
				case 0:
					self = .monthDate(MonthDate(year: nil, month: .Jan, day: Day(1), nthWeekday: nil))
				default:
					break
				}
			}

		}
	}

	func monthList() -> [String] {
		switch self {
		case .monthDate:
			return Month.allCases.map({$0.toString()})
		case .holidayDate:
			return HolidayName.allCases.map({$0.rawValue})
		}
	}
	func dayList() -> [String] {
		switch self {
		case .monthDate:
			return [" "] + Day.allCases.map({$0.toString()})
		case .holidayDate:
			return []
		}
	}

	var monthBinding: Int {
		get {
			switch self {
			case let .monthDate(mon):
				return mon.month.rawValue
			case let .holidayDate(hol):
				let index = HolidayName.allCases.firstIndex(of: hol.holiday)!
				return index
			}
		}
		set {
			switch self {
			case let .monthDate(mon):
				let newMonth = Month.allCases[newValue]
				self = .monthDate(MonthDate(year: mon.year, month: newMonth, day: mon.day, nthWeekday: mon.nthWeekday))
			case .holidayDate:
				let holidayName = HolidayName.allCases[newValue]
				self = .holidayDate(HolidayDate(year: nil, holiday: holidayName))
			}
		}
	}
	var dayBinding: Int {
		get {
			switch self {
			case let .monthDate(mon):
				return mon.day?.rawValue ?? 0
			case .holidayDate:
				return 0
			}
		}
		set {
			switch self {
			case let .monthDate(mon):
				self = .monthDate(MonthDate(year: mon.year, month: mon.month, day: Day(newValue), nthWeekday: mon.nthWeekday))
			case .holidayDate:
				break
			}
		}
	}

	func asMonthDate() -> MonthDate? {
		switch self {
		case let .monthDate(mon):
			return mon
		default:
			return nil
		}
	}
}

// "5:30-10:30"
struct HourRange: ParseElement {

	public var begin : Hour
	public var end : Hour
	public var plus : Bool

	static let defaultValue = HourRange(begin: Hour.time(10*60), end: Hour.time(18*60), plus: false)
	static let allDay = HourRange(begin: Hour.time(0), end: Hour.time(24*60), plus: false)
	static let daytime = HourRange(begin: Hour.sunrise(0), end: Hour.sunset(0), plus: false)

	static func scan(scanner:Scanner) -> HourRange?
	{
		if scanner.scanString("daytime") != nil ||
			scanner.scanString("day time") != nil
		{
			return HourRange.daytime
		}

		if let firstHour = Hour.scan(scanner: scanner) {
			let index = scanner.currentIndex
			if scanner.scanDash() != nil,
			   let lastHour = Hour.scan(scanner: scanner)
			{
				// 10:00-14:00
				let plus = scanner.scanString("+") != nil
				return HourRange(begin: firstHour, end: lastHour, plus: plus)
			}
			scanner.currentIndex = index
			// 12:00
			let plus = scanner.scanString("+") != nil
			return HourRange(begin: firstHour, end: Hour.none, plus: plus)
		}
		return nil
	}

	func toString() -> String
	{
		if end == Hour.none {
			return "\(begin.toString())\(plus ?"+":"")"
		} else {
			return "\(begin.toString())-\(end.toString())\(plus ?"+":"")"
		}
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

// "-39 days"
struct DayOffset: ParseElement {
	var offset: Int

	static let prefixChars = CharacterSet.init(charactersIn: "+-")

	static func scan(scanner: Scanner) -> DayOffset? {
		let index = scanner.currentIndex
		if let prefix = scanner.scanCharacters(from: prefixChars),
			prefix.count == 1,
			let off = scanner.scanInt(),
			scanner.scanWordPrefix("days", minLength: 3) != nil,	// "day" or "days"
			off > 0
		{
			let offset = prefix == "-" ? -off : off
			return DayOffset(offset: offset)
		}
		scanner.currentIndex = index
		return nil
	}

	func toString() -> String {
		return "\(offset > 0 ? "+" : "-")\(offset) \(abs(offset)==1 ? "day" : "days")"
	}
}

// "1-3"
struct NthEntry: ParseElement {
	var begin: Int
	var end: Int

	static func inRange(_ index:Int) -> Bool {
		return (index >= 1 && index <= 5) || (index >= -5 && index <= -1)
	}
	static func scan(scanner: Scanner) -> NthEntry? {
		let index = scanner.currentIndex
		if let begin = scanner.scanInt(),
		   inRange(begin)
		{
			let index2 = scanner.currentIndex
			if scanner.scanDash() != nil,
			   let end = scanner.scanInt(),
			   inRange(end),
			   begin > 0 && end > 0
			{
				return NthEntry(begin: begin, end: end)
			}
			scanner.currentIndex = index2
			return NthEntry(begin: begin, end: begin)
		}
		scanner.currentIndex = index
		return nil
	}

	func toString() -> String {
		if begin == end {
			return "\(begin)"
		} else {
			return "\(begin)-\(end)"
		}
	}
}

// "[-1,1-3]"
struct NthEntryList: ParseElement {
	var list:[NthEntry]

	static func scan(scanner: Scanner) -> NthEntryList? {
		let index = scanner.currentIndex
		if scanner.scanString("[") != nil,
		   let list:[NthEntry] = Util.parseList(scanner: scanner, scan:NthEntry.scan, delimiter: ","),
		   scanner.scanString("]") != nil
		{
			return NthEntryList(list:list)
		}
		scanner.currentIndex = index
		return nil
	}
	func toString() -> String {
		return "[" + Util.elementListToString(list: list, delimeter: ",") + "]"
	}
}

// "Mo-Fr" or "Mo[-1]" or "PH"
enum WeekdayRange: ParseElement {
	case holiday(PublicHoliday)
	case weekday(Weekday,NthEntryList?,DayOffset?)
	case weekdays(Weekday,Weekday)

	static let allDays = WeekdayRange.weekdays(.Mo, .Su)

	static func scan(scanner:Scanner) -> WeekdayRange?
	{
		if let holiday = PublicHoliday.scan(scanner: scanner) {
			return WeekdayRange.holiday(holiday)
		}
		if scanner.scanAnyWord(["Every Day","Everyday","Daily"]) != nil {
			return allDays
		}
		if scanner.scanAnyWord(["weekdays"]) != nil {
			return WeekdayRange.weekdays(.Mo, .Fr)
		}

		if let firstDay = Weekday.scan(scanner: scanner) {
			let index = scanner.currentIndex
			if scanner.scanDash() != nil,
			   let lastDay = Weekday.scan(scanner: scanner)
			{
				return WeekdayRange.weekdays(firstDay, lastDay)
			}
			scanner.currentIndex = index
			let nth = NthEntryList.scan(scanner: scanner)
			let offset = DayOffset.scan(scanner: scanner)
			return WeekdayRange.weekday(firstDay, nth, offset)
		}
		return nil
	}

	func toString() -> String {
		switch self {
		case let .holiday(holiday):
			return holiday.toString()
		case let .weekday(day, nth, offset):
			var s = day.toString()
			s += nth?.toString() ?? ""
			if let offset = offset {
				s += " " + offset.toString()
			}
			return s
		case let .weekdays(begin, end):
			return begin == end ? "\(begin)" : "\(begin)-\(end)"
		}
	}
}

// week "5-9"
struct WeekRange: ParseElement {
	var begin: Int
	var end: Int
	var slash: Int?

	static func scan(scanner: Scanner) -> WeekRange? {
		if let (begin,end):(Int,Int) = Util.parseRange(scanner: scanner, scan:{ scanner in
			let index = scanner.currentIndex
			if let item = scanner.scanInt(),
			   item >= 1 && item <= 53
			{
				return item
			} else {
				scanner.currentIndex = index
				return nil
			}})
		{
			let index = scanner.currentIndex
			if scanner.scanString("/") != nil,
			   let slash = scanner.scanInt(),
			   slash > 0
			{
				return WeekRange(begin: begin, end: end, slash: slash)
			}
			scanner.currentIndex = index
			return WeekRange(begin: begin, end: end, slash: nil)
		}
		return nil
	}

	static func scanList(scanner: Scanner) -> [WeekRange]? {
		let index = scanner.currentIndex
		if scanner.scanString("week") != nil,
		   let list = Util.parseList(scanner: scanner, scan: WeekRange.scan, delimiter: ",")
		{
			return list
		}
		scanner.currentIndex = index
		return nil
	}

	func toString() -> String {
		let base = begin == end ? "\(begin)" : "\(begin)-\(end)"
		let s = slash == nil ? "" : "\\\(slash!)"
		return base + s
	}
}

// "Apr 5-10" or "Apr 3-May 22"
struct MonthDayRange: ParseElement {
	var begin: DayOfYear
	var end: DayOfYear

	static let defaultValue = MonthDayRange(begin: DayOfYear.monthDate(MonthDate(month: .Jan, day: nil)),
											end: DayOfYear.monthDate(MonthDate(month: .Dec, day: nil)))

	static func scan(scanner: Scanner) -> MonthDayRange?
	{
		if let first = DayOfYear.scan(scanner: scanner) {
			let dashIndex = scanner.currentIndex
			if scanner.scanDash() != nil {
				if let monthDay = first.asMonthDate(),
				   monthDay.day != nil,
				   let day = Day.scan(scanner: scanner)
				{
					// "Apr 5-10"
					let last = DayOfYear.monthDate(MonthDate(month: monthDay.month, day: day))
					return MonthDayRange(begin: first, end: last)
				}
				// "Apr 5-May 10"
				if let last = DayOfYear.scan(scanner: scanner) {
					return MonthDayRange(begin: first, end: last)
				}
				scanner.currentIndex = dashIndex
			}
			return MonthDayRange(begin: first, end: first)
		}
		if scanner.scanWord("summer") != nil {
			return MonthDayRange(begin: DayOfYear.monthDate(MonthDate(year: nil, month: Month.Jun, day: nil, nthWeekday: nil)),
								 end: DayOfYear.monthDate(MonthDate(year: nil, month: Month.Aug, day: nil, nthWeekday: nil)))
		}
		if scanner.scanWord("winter") != nil {
			return MonthDayRange(begin: DayOfYear.monthDate(MonthDate(year: nil, month: Month.Dec, day: nil, nthWeekday: nil)),
								 end: DayOfYear.monthDate(MonthDate(year: nil, month: Month.Feb, day: nil, nthWeekday: nil)))
		}
		if scanner.scanWord("spring") != nil {
			return MonthDayRange(begin: DayOfYear.monthDate(MonthDate(year: nil, month: Month.Mar, day: nil, nthWeekday: nil)),
								 end: DayOfYear.monthDate(MonthDate(year: nil, month: Month.May, day: nil, nthWeekday: nil)))
		}
		if scanner.scanWord("autumn") != nil {
			return MonthDayRange(begin: DayOfYear.monthDate(MonthDate(year: nil, month: Month.Sep, day: nil, nthWeekday: nil)),
								 end: DayOfYear.monthDate(MonthDate(year: nil, month: Month.Nov, day: nil, nthWeekday: nil)))
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
}

// "Dec 1-5,10-12,25,31, Jan 1-Mar 15, Apr 3-May 22"
struct MonthDayRangeList {
	// this is used just for parsing, though it could easily be converted to a standalone class
	static func scan(scanner: Scanner) -> [MonthDayRange]? {
		var list = [MonthDayRange]()
		var delimiterIndex: String.Index? = nil
		repeat {

			if let prev = list.last,
			   let mon1 = prev.begin.asMonthDate(),
			   let mon2 = prev.end.asMonthDate(),
			   mon1.month == mon2.month,
			   mon1.day != nil && mon2.day != nil,
			   mon1.year == nil && mon2.year == nil,
			   let days = Util.parseListRange(scanner: scanner, scan: Day.scan, delimiter: ",")
			{
				// "Dec 1-5,10-12,25,31"
				for (begin,end) in days {
					list.append(MonthDayRange(begin: DayOfYear.monthDate(MonthDate(year: nil, month: mon1.month, day: begin, nthWeekday: nil)),
											  end: DayOfYear.monthDate(MonthDate(year: nil, month: mon1.month, day: end, nthWeekday: nil))))
				}
			} else {
				guard let item = MonthDayRange.scan(scanner: scanner) else {
					// back up to before preceding comma
					if let delimiterIndex = delimiterIndex {
						scanner.currentIndex = delimiterIndex
						return list
					} else {
						return nil
					}
				}
				list.append(item)
			}
			delimiterIndex = scanner.currentIndex
		} while scanner.scanString(",") != nil
		return list
	}
}


// "Mo-Fr 6:00-18:00, Sa,Su 6:00-12:00"
struct DaysHours: ParseElement {

	var weekdays : [WeekdayRange]
	var holidays : [PublicHoliday]
	var holidayFilter : [PublicHoliday] // for space-seperated days: "PH Sa-Su" (i.e. holidays that fall on a weekend)
	var hours : [HourRange]

	static let everyDay:Set<Int> = [0,1,2,3,4,5,6]

	static let all247 = [ "24/7",
						  "24x7",
						  "0-24",
						  "24 hour",
						  "24 hours",
						  "24 hrs",
						  "24hours",
						  "24hr",
						  "All day",
						  "24 Horas"
	]

	static func scan(scanner: Scanner) -> DaysHours?
	{
		if scanner.scanAnyWord(all247) != nil {
			return DaysHours.hours_24_7
		}

		// holidays are supposed to come first, but we support either order:
		let holidays1 : [PublicHoliday] = Util.parseList(scanner: scanner, scan: PublicHoliday.scan, delimiter: ",") ?? []
		let comma1 = holidays1.count > 0 && scanner.scanString(",") != nil
		let weekdays : [WeekdayRange] = Util.parseList(scanner: scanner, scan: WeekdayRange.scan, delimiter: ",") ?? []
		let comma2 = weekdays.count > 0 && scanner.scanString(",") != nil
		let holidays2 : [PublicHoliday] = Util.parseList(scanner: scanner, scan:PublicHoliday.scan, delimiter: ",") ?? []
		_ = scanner.scanString(":")	// misplaced readability separator
		let from = scanner.scanWord("from")	// confused users
		var hours : [HourRange] = Util.parseList(scanner: scanner, scan: HourRange.scan, delimiter: ",") ?? []
		if weekdays.count == 0 && holidays1.count == 0 && holidays2.count == 0 && hours.count == 0 {
			return nil
		}

		if from != nil,
		   hours.count == 1,
		   let hour = hours.last,
		   hour.end == hour.begin
		{
			// convert "from 6:00" -> "6:00+"
			hours = [HourRange(begin: hour.begin, end: hour.end, plus: true)]
		}

		if comma1 && comma2 {
			return DaysHours(weekdays: weekdays,
							 holidays: holidays1+holidays2,
							 holidayFilter: [],
							 hours: hours)
		}
		if comma1 {
			return DaysHours(weekdays: weekdays,
							 holidays: holidays1,
							 holidayFilter: holidays2,
							 hours: hours)
		}
		if comma2 {
			return DaysHours(weekdays: weekdays,
							 holidays: holidays2,
							 holidayFilter: holidays1,
							 hours: hours)
		}
		return DaysHours(weekdays: weekdays,
						 holidays: [],
						 holidayFilter: holidays1+holidays2,
						 hours: hours)
	}


	func toString() -> String {
		let days = Util.elementListToString(list: weekdays, delimeter: ",")
		let holi = Util.elementListToString(list: holidays, delimeter: ",")
		let filter = Util.elementListToString(list: holidayFilter, delimeter: ",")
		let hrs = Util.elementListToString(list: hours, delimeter: ",")

		let days2 = Util.stringListToString(list: [holi,days], delimeter: ",")
		return Util.stringListToString(list: [filter,days2,hrs], delimeter: " ")
	}

	static let defaultValue = DaysHours(weekdays: [WeekdayRange.allDays],
										holidays: [],
										holidayFilter: [],
										hours: [HourRange.defaultValue])
	static let hours_24_7 = DaysHours(weekdays: [],
									  holidays: [],
									  holidayFilter: [],
									  hours: [HourRange.allDay])

	func is24_7() -> Bool {
		if weekdays.count == 0,
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

	static func weekdaysSet(days:[WeekdayRange]) -> Set<Int> {
		var set = Set<Int>()
		for dayRange in days {
			switch dayRange {
				case let .weekday(day, _, _):
					set.insert(day.rawValue)
				case let .weekdays(begin, end):
					for day in begin.rawValue...end.rawValue {
						set.insert(day)
					}
				case .holiday:
					break
			}
		}
		return set
	}

	static func holidaysSet(days:[WeekdayRange]) -> Set<PublicHoliday> {
		var set = Set<PublicHoliday>()
		for day in days {
			switch day {
				case .weekday,
					 .weekdays:
					break
				case let .holiday(holiday):
					set.insert(holiday)
			}
		}
		return set
	}

	func weekdaysSet() -> Set<Int> {
		return DaysHours.weekdaysSet(days:weekdays)
	}

	func holidaysSet() -> Set<PublicHoliday> {
		return DaysHours.holidaysSet(days:weekdays)
	}

	static func dayRangesForWeekdaysSet( _ set: Set<Int> ) -> [WeekdayRange] {
		var newrange = [WeekdayRange]()
		var range: (Weekday,Weekday)? = nil

		for d in 0..<7 {
			if set.contains(d) {
				let day = Weekday(rawValue: d)!
				if let (begin,end) = range,
				   end.rawValue+1 == d
				{
					// extends last range
					range = (begin,day)
				} else {
					// start a new range
					if let (begin,end) = range {
						newrange.append(WeekdayRange.weekdays(begin,end))
					}
					range = (day,day)
				}
			}
		}
		if let (begin,end) = range {
			newrange.append(WeekdayRange.weekdays(begin,end))
		}
		return newrange
	}

	mutating func toggleDay(day:Int) -> Void {
		var set = weekdaysSet()

		if set.isEmpty {
			set = DaysHours.everyDay
		}
		if set.contains(day) {
			set.remove(day)
		} else {
			set.insert(day)
		}
		if set == DaysHours.everyDay {
			self.weekdays = []
			return
		}
		self.weekdays = DaysHours.dayRangesForWeekdaysSet(set)
	}
}

enum RuleSeparator: String, CaseIterable, ParseElement {
	case semiColon = ";"
	case comma = ","
	case doubleBar = "||"

	static func scan(scanner: Scanner) -> RuleSeparator? {
		for item in RuleSeparator.allCases {
			if scanner.scanString(item.rawValue) != nil {
				return item
			}
		}
		return nil
	}

	func toString() -> String {
		return self.rawValue + " "
	}
}

// "Jan-Sep M-F 10:00-18:00"
struct MonthsDaysHours: ParseElement {

	var months: [MonthDayRange]
	var weeks: [WeekRange]
	var readabilitySeparator: String?
	var daysHours: [DaysHours]
	var modifier : Modifier?
	var comment : Comment?
	var ruleSeparator : RuleSeparator?

	static func scan(scanner:Scanner) -> MonthsDaysHours?
	{
		let months : [MonthDayRange] = MonthDayRangeList.scan(scanner: scanner) ?? []
		let weeks : [WeekRange] = WeekRange.scanList(scanner: scanner) ?? []
		let readabilitySeparator = scanner.scanString(":")
		let daysHours : [DaysHours] = Util.parseList(scanner: scanner, scan: DaysHours.scan, delimiter: ",") ?? []
		let modifier = Modifier.scan(scanner: scanner)
		let comment = Comment.scan(scanner: scanner)
		if months.count == 0 && daysHours.count == 0 && modifier == nil && comment == nil {
			return nil
		}
		let ruleSeparator = RuleSeparator.scan(scanner: scanner)
		return MonthsDaysHours(months: months,
							   weeks: weeks,
							   readabilitySeparator: readabilitySeparator,
							   daysHours: daysHours,
							   modifier: modifier,
							   comment: comment,
							   ruleSeparator: ruleSeparator)
	}

	func toString() -> String {
		return toString(withRuleSeparator:true)
	}
	func toString(withRuleSeparator:Bool) -> String {
		if is24_7() {
			return "24/7"
		}
		let m = Util.elementListToString(list: months, delimeter: ",")
		let dh = Util.elementListToString(list: daysHours, delimeter: ", ")
		let a = [m,
				 readabilitySeparator,
				 dh,
				 modifier?.toString(),
				 comment?.toString()]
		var r = Util.stringListToString(list: a, delimeter: " ")
		if withRuleSeparator {
			r += ruleSeparator?.toString() ?? ""
		}
		return r
	}

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
			return result.union(dayHours.weekdaysSet())
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
			dh.weekdays = DaysHours.dayRangesForWeekdaysSet( set )
		}
		daysHours.append(dh)
	}
	mutating func deleteDaysHours(at index:Int) -> Void {
		daysHours.remove(at: index)
	}
}

struct RuleList: ParseElement {
	var rules : [MonthsDaysHours]

	static func scan(scanner: Scanner) -> RuleList? {
		if let list : [MonthsDaysHours] = Util.parseList(scanner: scanner, scan: MonthsDaysHours.scan, delimiter: "" ) {
			return RuleList(rules: list)
		}
		return nil
	}

	func toString() -> String {
		var s = ""
		for index in rules.indices {
			let i = rules[index].toString(withRuleSeparator: index < rules.count-1)
			s += i
		}
		return s
	}

	static let emptyValue = RuleList(rules: [])

	mutating func appendMonthDayHours() -> Void {
		rules.append(MonthsDaysHours(months: [],
									 weeks: [],
									 daysHours: [DaysHours(weekdays: [WeekdayRange.allDays],
														   holidays: [],
														   holidayFilter: [],
														   hours: [HourRange.defaultValue])],
									 ruleSeparator: .semiColon))
	}
}

import SwiftUI

class OpeningHours: ObservableObject, CustomStringConvertible {

	@Published var ruleList : RuleList {
		didSet {
			if let binding = binding {
				DispatchQueue.main.async {	binding.wrappedValue = self.string }
			}
		}
	}
	private var stringRaw : String
	private var errorIndex : String.Index?
	var binding: Binding<String>?

	var string: String {
		get {
			if errorIndex == nil {
				return toString()
			}
			return stringRaw
		}
		set {
			let (rules,errorLoc) = OpeningHours.parseString(newValue)
			self.stringRaw = newValue
			self.errorIndex = errorLoc
			if let rules = rules {
				ruleList = rules
			}
		}
	}

	public init() {
		self.ruleList = RuleList.emptyValue
		self.errorIndex = nil
		self.stringRaw = ""
		self.binding = nil
	}
	public convenience init(string:String) {
		self.init()
		self.string = string
	}
	public convenience init(binding:Binding<String>) {
		self.init()
		self.binding = binding
		self.string = binding.wrappedValue
	}

	static func parseString(_ text:String) -> (RuleList?,String.Index?) {
		let scanner = Scanner(string: text)
		scanner.caseSensitive = false
		scanner.charactersToBeSkipped = CharacterSet.whitespaces

		if let rules = RuleList.scan(scanner: scanner),
		   scanner.isAtEnd
		{
			// success
			return (rules,nil)
		}
		return (nil,scanner.currentIndex)
	}

	func addMonthDayHours() -> Void {
		self.ruleList.appendMonthDayHours()
	}

	func toString() -> String {
		return ruleList.toString()
	}

	public var description: String {
		return toString()
	}

	var errorPosition: Int {
		var pos = 0
		var index = stringRaw.startIndex
		while index != errorIndex {
			index = stringRaw.index(after: index)
			pos += 1
		}
		return pos
	}

	func printErrorMessage() {
		print("\(stringRaw)")
		if errorIndex != nil {
			var s = ""
			for _ in 0..<errorPosition {
				s += "-"
			}
			s += "^"
			print("\(s)")
		}
	}
}
