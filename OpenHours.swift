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
func parseRange<T>(scanner:Scanner, scan:(Scanner)->T? ) -> (T,T)? {
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
func parseList<T>(scanner:Scanner, scan:(Scanner)->T?, delimiter:String) -> [T]?
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
func parseListRange<T>(scanner: Scanner, scan:(Scanner)->T?, delimiter:String) -> [(T,T)]? {
	return parseList(scanner: scanner,
					 scan: { scanner in	return parseRange(scanner: scanner, scan: scan) },
					 delimiter: delimiter)
}

func stringListToString(list: [String?], delimeter:String) -> String
{
	return list.reduce("") { result, next in
		if let next = next,
		   next.count > 0 {
			return result == "" ? next : result + delimeter + next
		} else {
			return result
		}
	}
}
func elementListToString<T:ParseElement>(list: [T], delimeter:String) -> String
{
	return list.reduce("") { result, next in
		return result == "" ? next.toString() : result + delimeter + next.toString()
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
	case sunrise
	case sunset
	case dawn
	case dusk
	case time(Int)
	case none			// used when trailing time of a range is missing

	// time must be first here:
	static var allCases: [Hour] = [.time(0),.sunrise,.sunset,.dawn,.dusk,.none]

	func isTime() -> Bool {
		switch self {
		case .time:
			return true
		default:
			return false
		}
	}

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
				scanner.charactersToBeSkipped = skipped
				if scanner.scanWord("AM") != nil {
					return .time((hour%12)*60+minute)
				}
				if scanner.scanWord("PM") != nil {
					return .time((12+hour%12)*60+minute)
				}
				return .time(hour*60+minute)
			}

			scanner.charactersToBeSkipped = skipped
			scanner.currentIndex = index2
			if scanner.scanWord("AM") != nil {
				return .time((hour%12)*60)
			}
			if scanner.scanWord("PM") != nil {
				return .time((12+(hour%12))*60)
			}
		}
		scanner.currentIndex = index
		scanner.charactersToBeSkipped = skipped

		// named times
		if scanner.scanWord("sunrise") != nil {
			return .sunrise
		}
		if scanner.scanWord("sunset") != nil {
			return .sunset
		}
		if scanner.scanWord("dawn") != nil {
			return .dawn
		}
		if scanner.scanWord("dusk") != nil {
			return .dusk
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
		case .dawn:
			return "dawn"
		case .dusk:
			return "dusk"
		case .none:
			return "none"
		case let .time(time):
			let hour = time/60
			let minute = time%60
			return String(format: "%02d:%02d", arguments: [hour,minute])
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

enum Holiday: String, CaseIterable, ParseElement {
	case PH = "PH"
	case SH = "SH"

	static func scan(scanner: Scanner) -> Holiday? {
		for value in Holiday.allCases {
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
	var day : Int

	init?(_ d:Int) {
		if d < 1 || d > 31 {
			return nil
		}
		self.day = d
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
		return "\(self.day)"
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
	var year: Int

	static func == (lhs: Year, rhs: Year) -> Bool {
		return lhs.year == rhs.year
	}

	static func scan(scanner: Scanner) -> Year? {
		let index = scanner.currentIndex
		if let year = scanner.scanInt(),
		   year >= 1900
		{
			return Year(year: year)
		}
		scanner.currentIndex = index
		return nil
	}

	func toString() -> String {
		return "\(self.year)"
	}
}

// "Jan" or "Jan 5"
struct MonthDay: ParseElement {
	var year: Year?
	var month: Month
	var day: Day?					// day and nthWeekday are mutually exclusive
	var nthWeekday: NthWeekday?

	static func scan(scanner:Scanner) -> MonthDay?
	{
		let index = scanner.currentIndex
		let year = Year.scan(scanner: scanner)
		if let mon = Month.scan(scanner: scanner) {
			let index2 = scanner.currentIndex
			if let _ = HourRange.scan(scanner: scanner) {
				// "Apr 5:30-6:30"
				scanner.currentIndex = index2
				return MonthDay(year: year, month: mon, day: nil)
			}
			if let day = Day.scan(scanner: scanner) {
				// "Apr 5"
				return MonthDay(year: year, month: mon, day: day)
			}
			if let nthWeekday = NthWeekday.scan(scanner: scanner) {
				// "Apr Fri[-1]"
				return MonthDay(year: year, month: mon, day: nil, nthWeekday: nthWeekday)
			}
			return MonthDay(year: year, month: mon, day: nil)
		}
		scanner.currentIndex = index
		return nil
	}

	func toString() -> String {
		let d = day != nil ? "\(day!)" : nthWeekday != nil ? nthWeekday!.toString() : nil
		let a = [year?.toString(), month.toString(), d]
		return OpeningHours.stringListToString(list: a, delimeter: " ")
	}
}

// "5:30-10:30"
struct HourRange: ParseElement {

	public var begin : Hour
	public var end : Hour
	public var plus : Bool

	static let defaultValue = HourRange(begin: Hour.time(10*60), end: Hour.time(18*60), plus: false)
	static let allDay = HourRange(begin: Hour.time(0), end: Hour.time(24*60), plus: false)

	static func scan(scanner:Scanner) -> HourRange?
	{
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

struct NthEntryList: ParseElement {
	var list:[NthEntry]

	static func scan(scanner: Scanner) -> NthEntryList? {
		let index = scanner.currentIndex
		if scanner.scanString("[") != nil,
		   let list:[NthEntry] = parseList(scanner: scanner, scan:NthEntry.scan, delimiter: ","),
		   scanner.scanString("]") != nil
		{
			return NthEntryList(list:list)
		}
		scanner.currentIndex = index
		return nil
	}
	func toString() -> String {
		return OpeningHours.elementListToString(list: list, delimeter: ",")
	}
}

// "Mo-Fr" or "Mo[-1]" or "PH"
enum WeekdayRange: ParseElement {
	case holiday(Holiday)
	case weekday(Weekday,NthEntryList?)
	case weekdays(Weekday,Weekday)

	static let everyWeekday = WeekdayRange.weekdays(.Mo, .Su)

	static func scan(scanner:Scanner) -> WeekdayRange?
	{
		if let holiday = Holiday.scan(scanner: scanner) {
			return WeekdayRange.holiday(holiday)
		}
		if scanner.scanString("Every Day") != nil ||
			scanner.scanString("Everyday") != nil ||
			scanner.scanString("Daily") != nil
		{
			return everyWeekday
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
			return WeekdayRange.weekday(firstDay, nth)
		}
		return nil
	}

	func toString() -> String {
		switch self {
		case let .holiday(holiday):
			return holiday.toString()
		case let .weekday(day, nth):
			if let nth = nth {
				return "\(day)[\(nth)]"
			}
			return "\(day)"
		case let .weekdays(begin, end):
			return "\(begin)-\(end)"
		}
	}
}

// "Apr 5-10" or "Apr 3-May 22"
struct MonthDayRange: ParseElement {
	var begin: MonthDay
	var end: MonthDay

	static let defaultValue = MonthDayRange(begin: MonthDay(month: .Jan, day: nil),
											end: MonthDay(month: .Dec, day: nil))

	static func scan(scanner: Scanner) -> MonthDayRange?
	{
		if let first = MonthDay.scan(scanner: scanner) {
			let dashIndex = scanner.currentIndex
			if scanner.scanDash() != nil {
				if first.day != nil,
				   let day = Day.scan(scanner: scanner)
				{
					// "Apr 5-10"
					let last = MonthDay(month: first.month, day: day)
					return MonthDayRange(begin: first, end: last)
				}
				// "Apr 5-May 10"
				if let last = MonthDay.scan(scanner: scanner) {
					return MonthDayRange(begin: first, end: last)
				}
				scanner.currentIndex = dashIndex
			}
			return MonthDayRange(begin: first, end: first)
		}
		if scanner.scanString("summer") != nil {
			return MonthDayRange(begin: MonthDay(year: nil, month: Month.Jun, day: nil, nthWeekday: nil),
								 end: MonthDay(year: nil, month: Month.Aug, day: nil, nthWeekday: nil))
		}
		if scanner.scanString("winter") != nil {
			return MonthDayRange(begin: MonthDay(year: nil, month: Month.Dec, day: nil, nthWeekday: nil),
								 end: MonthDay(year: nil, month: Month.Feb, day: nil, nthWeekday: nil))
		}
		if scanner.scanString("spring") != nil {
			return MonthDayRange(begin: MonthDay(year: nil, month: Month.Mar, day: nil, nthWeekday: nil),
								 end: MonthDay(year: nil, month: Month.May, day: nil, nthWeekday: nil))
		}
		if scanner.scanString("autumn") != nil {
			return MonthDayRange(begin: MonthDay(year: nil, month: Month.Sep, day: nil, nthWeekday: nil),
								 end: MonthDay(year: nil, month: Month.Nov, day: nil, nthWeekday: nil))
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

struct MonthDayRangeList {
	// this is used just for parsing, though it could easily be converted to a standalone class
	static func scan(scanner: Scanner) -> [MonthDayRange]? {
		var list = [MonthDayRange]()
		var delimiterIndex: String.Index? = nil
		repeat {

			if let last = list.last,
			   last.begin.month == last.end.month,
			   last.begin.day != nil && last.end.day != nil,
			   last.begin.year == nil,
			   let days = parseListRange(scanner: scanner, scan: Day.scan, delimiter: ",")
			{
				// "Dec 1-5,10-12,25,31"
				for (begin,end) in days {
					list.append(MonthDayRange(begin: MonthDay(year: nil, month: last.begin.month, day: begin, nthWeekday: nil),
											  end: MonthDay(year: nil, month: last.begin.month, day: end, nthWeekday: nil)))
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
	var holidays : [Holiday]
	var holidayFilter : [Holiday] // for space-seperated days: "PH Sa-Su" (i.e. holidays that fall on a weekend)
	var hours : [HourRange]

	static let everyDay:Set<Int> = [0,1,2,3,4,5,6]

	static let all247 = [ "24/7",
						  "24x7",
						  "0-24",
						  "24 hour",
						  "24 hours",
						  "24hours",
						  "24hr",
						  "All day",
	]

	static func scan(scanner: Scanner) -> DaysHours?
	{
		for text in all247 {
			if scanner.scanString(text) != nil {
				return DaysHours.hours_24_7
			}
		}

		// holidays are supposed to come first, but we support either order:
		let holidays1 : [Holiday] = parseList(scanner: scanner, scan: Holiday.scan, delimiter: ",") ?? []
		let comma1 = holidays1.count > 0 && scanner.scanString(",") != nil
		let weekdays : [WeekdayRange] = parseList(scanner: scanner, scan: WeekdayRange.scan, delimiter: ",") ?? []
		let comma2 = weekdays.count > 0 && scanner.scanString(",") != nil
		let holidays2 : [Holiday] = parseList(scanner: scanner, scan:Holiday.scan, delimiter: ",") ?? []
		_ = scanner.scanString(":")	// misplaced readability separator
		let from = scanner.scanString("from")	// confused users
		var hours : [HourRange] = parseList(scanner: scanner, scan: HourRange.scan, delimiter: ",") ?? []
		if weekdays.count == 0 && holidays1.count == 0 && holidays2.count == 0 && hours.count == 0 {
			return nil
		}

		if from != nil,
		   hours.count == 1,
		   let hour = hours.last,
		   hour.end == hour.begin
		{
			// convert "from 6:00" to "6:00+"
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
		// illegal, but we'll treat it as two holiday filters
		return DaysHours(weekdays: weekdays,
						 holidays: [],
						 holidayFilter: holidays1+holidays2,
						 hours: hours)
	}


	func toString() -> String {
		let days = OpeningHours.elementListToString(list: weekdays, delimeter: ",")
		let holi = OpeningHours.elementListToString(list: holidays, delimeter: ",")
		let filter = OpeningHours.elementListToString(list: holidayFilter, delimeter: ",")
		let hrs = OpeningHours.elementListToString(list: hours, delimeter: ",")

		let days2 = OpeningHours.stringListToString(list: [holi,days], delimeter: ",")
		return OpeningHours.stringListToString(list: [filter,days2,hrs], delimeter: " ")
	}

	static let defaultValue = DaysHours(weekdays: [WeekdayRange.everyWeekday],
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
				case let .weekday(day, _):
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

	static func holidaysSet(days:[WeekdayRange]) -> Set<Holiday> {
		var set = Set<Holiday>()
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

	func holidaysSet() -> Set<Holiday> {
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
	var readabilitySeparator: String?
	var daysHours: [DaysHours]
	var modifier : Modifier?
	var comment : Comment?
	var ruleSeparator : RuleSeparator?

	static func scan(scanner:Scanner) -> MonthsDaysHours?
	{
		let months : [MonthDayRange] = MonthDayRangeList.scan(scanner: scanner) ?? []
		let readabilitySeparator = scanner.scanString(":")
		let daysHours : [DaysHours] = parseList(scanner: scanner, scan: DaysHours.scan, delimiter: ",") ?? []
		let modifier = Modifier.scan(scanner: scanner)
		let comment = Comment.scan(scanner: scanner)
		if months.count == 0 && daysHours.count == 0 && modifier == nil && comment == nil {
			return nil
		}
		let ruleSeparator = RuleSeparator.scan(scanner: scanner)
		return MonthsDaysHours(months: months,
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
		let m = OpeningHours.elementListToString(list: months, delimeter: ",")
		let dh = OpeningHours.elementListToString(list: daysHours, delimeter: ", ")
		let a = [m,
				 readabilitySeparator,
				 dh,
				 modifier?.toString(),
				 comment?.toString()]
		var r = OpeningHours.stringListToString(list: a, delimeter: " ")
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
		if let list : [MonthsDaysHours] = parseList(scanner: scanner, scan: MonthsDaysHours.scan, delimiter: "" ) {
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
									 daysHours: [DaysHours(weekdays: [WeekdayRange.everyWeekday],
														   holidays: [],
														   holidayFilter: [],
														   hours: [HourRange.defaultValue])],
									 ruleSeparator: .semiColon))
	}
}

class OpenHours: ObservableObject, CustomStringConvertible {

	@Published var ruleList : RuleList
	private var textual : String
	private var errorIndex : String.Index?

	var string: String {
		get {
			if ruleList.rules.count > 0 {
				textual = toString()
			}
			return textual
		}
		set {
			let (result,errorLoc) = OpenHours.parseString(newValue)
			if let result = result {
				ruleList = result
				textual = toString()
			} else {
				textual = newValue
			}
			self.errorIndex = errorLoc
		}
	}

	init(fromString text:String) {
		textual = text
		let (result,errorLoc) = OpenHours.parseString(text)
		self.ruleList = result ?? RuleList.emptyValue
		self.errorIndex = errorLoc
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

	var description: String {
		return toString()
	}

	var errorPosition: Int {
		var pos = 0
		var index = textual.startIndex
		while index != errorIndex {
			index = textual.index(after: index)
			pos += 1
		}
		return pos
	}

	func printErrorMessage() {
		print("\(textual)")
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
