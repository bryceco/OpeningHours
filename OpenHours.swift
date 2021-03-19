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

	static let dashCharacters = CharacterSet.init(charactersIn: "-–‐‒–—―") // - %u2013 %u2010 %u2012 %u2013 %u2014 %u2015
	func scanDash() -> String? {
		if let dash = self.scanCharacters(from: Scanner.dashCharacters) {
			// could end up with several dashes in a row but that shouldn't hurt anything
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

func parseList<T:ParseElement>(scanner:Scanner, delimiter:String) -> [T]?
{
	var list = [T]()
	var delimiterIndex: String.Index? = nil

	repeat {
		guard let item = T.scan(scanner:scanner) else {
			// back up to before preceding comma
			if let commaIndex = delimiterIndex {
				scanner.currentIndex = commaIndex
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

func toString(list: [String?], delimeter:String) -> String
{
	return list.reduce("") { result, next in
		if let next = next {
			return result == "" ? next : result + delimeter + next
		} else {
			return result
		}
	}
}
func toString<T:ParseElement>(list: [T], delimeter:String) -> String
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
enum Hour: ParseElement {

	case sunrise
	case sunset
	case dawn
	case dusk
	case indefinite	// used for end-time in 6:00+ notation
	case time(Int)

	static let minuteSeperators = CharacterSet(charactersIn: ":_")
	static func scan(scanner:Scanner) -> Hour?
	{
		let index = scanner.currentIndex
		let skipped = scanner.charactersToBeSkipped
		scanner.charactersToBeSkipped = nil
		_ = scanner.scanCharacters(from: CharacterSet.whitespacesAndNewlines)
		if let hour = scanner.scanInt(),
		   scanner.scanCharacters(from: minuteSeperators)?.count == 1,
		   let minute = scanner.scanInt()
		{
			scanner.charactersToBeSkipped = skipped
			return .time(hour*60+minute)
		} else {
			scanner.currentIndex = index
		}
		scanner.charactersToBeSkipped = skipped

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
		case let .time(time):
			let hour = time/60
			let minute = time%60
			return String(format: "%02d:%02d", arguments: [hour,minute])
		case .indefinite:
			assert(false)
			return "+"
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

	static let synonyms = [
		["Monday"],
		["Tuesday"],
		["Wednesday"],
		["Thursday"],
		["Friday"],
		["Saturday"],
		["Sunday"]
	]

	static func scan(scanner:Scanner) -> Day?
	{
		for day in synonyms.indices {
			for text in synonyms[day] {
				if scanner.scanWordPrefix(text, minLength: 2) != nil {
					return Day(rawValue: day)
				}
			}
		}
		return nil
	}

	func toString() -> String {
		return Day.synonyms[self.rawValue][0]
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
	var day: Int?

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
			if let day = scanner.scanInt() {
				// "Apr 5"
				return MonthDay(year: year, month: mon, day: day)
			} else {
				return MonthDay(year: year, month: mon, day: nil)
			}
		}
		scanner.currentIndex = index
		return nil
	}

	func toString() -> String {
		let a = [year?.toString(), month.toString(), day == nil ? nil : "\(day!)"]
		return OpeningHours.toString(list: a, delimeter: " ")
	}
}

// "5:30-10:30"
struct HourRange: ParseElement {

	public var begin : Hour
	public var end : Hour

	static let defaultValue = HourRange(begin: Hour.time(10*60), end: Hour.time(18*60))
	static let allDay = HourRange(begin: Hour.time(0), end: Hour.time(24*60))

	static func scan(scanner:Scanner) -> HourRange?
	{
		if let firstHour = Hour.scan(scanner: scanner) {
			let index = scanner.currentIndex
			if scanner.scanDash() != nil,
			   let lastHour = Hour.scan(scanner: scanner)
			{
				return HourRange(begin: firstHour, end: lastHour)
			}
			scanner.currentIndex = index
			if scanner.scanString("+") != nil {
				return HourRange(begin: firstHour, end: Hour.indefinite)
			} else {
				return HourRange(begin: firstHour, end: firstHour)
			}
		}
		return nil
	}

	func toString() -> String
	{
		if end == Hour.indefinite {
			return "\(begin.toString())+"
		} else {
			return "\(begin.toString())-\(end.toString())"
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
			   inRange(end)
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
		   let list:[NthEntry] = parseList(scanner: scanner, delimiter: ","),
		   scanner.scanString("]") != nil
		{
			return NthEntryList(list:list)
		}
		scanner.currentIndex = index
		return nil
	}
	func toString() -> String {
		return OpeningHours.toString(list: list, delimeter: ",")
	}
}

// "Mo-Fr" or "Mo[-1]" or "PH"
enum DayRange: ParseElement {
	case holiday(Holiday)
	case weekday(Day,NthEntryList?)
	case weekdays(Day,Day)

	static let defaultValue = DayRange.weekdays(.Mo, .Su)

	static func scan(scanner:Scanner) -> DayRange?
	{
		if let holiday = Holiday.scan(scanner: scanner) {
			return DayRange.holiday(holiday)
		}
		if let firstDay = Day.scan(scanner: scanner) {
			let index = scanner.currentIndex
			if scanner.scanDash() != nil,
			   let lastDay = Day.scan(scanner: scanner)
			{
				return DayRange.weekdays(firstDay, lastDay)
			}
			scanner.currentIndex = index
			let nth = NthEntryList.scan(scanner: scanner)
			return DayRange.weekday(firstDay, nth)
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

	static let defaultValue = MonthDayRange(begin: MonthDay(month: .Jan, day: nil), end: MonthDay(month: .Dec, day: nil))

	static func scan(scanner: Scanner) -> MonthDayRange?
	{
		if let first = MonthDay.scan(scanner: scanner) {
			let dashIndex = scanner.currentIndex
			if scanner.scanDash() != nil {
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
				scanner.currentIndex = dashIndex
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
}

// "Mo-Fr 6:00-18:00, Sa,Su 6:00-12:00"
struct DaysHours: ParseElement {

	var days : [DayRange]
	var hours : [HourRange]

	static let everyDay:Set<Int> = [0,1,2,3,4,5,6]

	static func scan(scanner: Scanner) -> DaysHours?
	{
		if scanner.scanString("24/7") != nil ||
			scanner.scanString("24 hours") != nil ||
			scanner.scanString("24") != nil
		{
			return DaysHours.hours_24_7
		}

		// need to parse days twice, because spaces are allowed to seperate ranges of days/holidays
		let days1 : [DayRange] = parseList(scanner: scanner, delimiter: ",") ?? []
		let days2 : [DayRange] = parseList(scanner: scanner, delimiter: ",") ?? []
		let days = days1 + days2
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

	func weekdaysSet() -> Set<Int> {
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

	func holidaysSet() -> Set<Holiday> {
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

	static func dayRangesForWeekdaysSet( _ set: Set<Int> ) -> [DayRange] {
		var newrange = [DayRange]()
		var range: (Day,Day)? = nil

		for d in 0..<7 {
			if set.contains(d) {
				let day = Day(rawValue: d)!
				if let (begin,end) = range,
				   end.rawValue+1 == d
				{
					// extends last range
					range = (begin,day)
				} else {
					// start a new range
					if let (begin,end) = range {
						newrange.append(DayRange.weekdays(begin,end))
					}
					range = (day,day)
				}
			}
		}
		if let (begin,end) = range {
			newrange.append(DayRange.weekdays(begin,end))
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
			self.days = []
			return
		}
		self.days = DaysHours.dayRangesForWeekdaysSet(set)
	}

	func toString() -> String {
		let s1 = OpeningHours.toString(list: days, delimeter: ",")
		let s2 = OpeningHours.toString(list: hours, delimeter: ",")
		return s1.count > 0 && s2.count > 0 ? s1+" "+s2 : s1+s2
	}
}

// "Jan-Sep M-F 10:00-18:00"
struct MonthsDaysHours: ParseElement {

	var months: [MonthDayRange]
	var readabilitySeperator: String?
	var daysHours: [DaysHours]
	var modifier : Modifier?
	var comment : Comment?

	static func scan(scanner:Scanner) -> MonthsDaysHours?
	{
		let months : [MonthDayRange] = parseList(scanner: scanner, delimiter: ",") ?? []
		let readabilitySeperator = scanner.scanString(":")
		let daysHours : [DaysHours] = parseList(scanner: scanner, delimiter: ",") ?? []
		let modifier = Modifier.scan(scanner: scanner)
		let comment = Comment.scan(scanner: scanner)
		if months.count == 0 && daysHours.count == 0 && modifier == nil && comment == nil {
			return nil
		}
		return MonthsDaysHours(months: months,
							   readabilitySeperator: readabilitySeperator,
							   daysHours: daysHours,
							   modifier: modifier,
							   comment: comment)
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
			dh.days = DaysHours.dayRangesForWeekdaysSet( set )
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
}

class OpenHours: ObservableObject, CustomStringConvertible {

	@Published var groups : [MonthsDaysHours]
	private var textual : String
	private var errorIndex : String.Index?

	var string: String {
		get {
			if groups.count > 0 {
				textual = toString()
			}
			return textual
		}
		set {
			let (result,errorLoc) = OpenHours.parseString(newValue)
			if let result = result {
				groups = result
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
		self.groups = result ?? []
		self.errorIndex = errorLoc
	}

	static func parseString(_ text:String) -> ([MonthsDaysHours]?,String.Index?) {
		let scanner = Scanner(string: text)
		scanner.caseSensitive = false
		scanner.charactersToBeSkipped = CharacterSet.whitespaces

		if let result : [MonthsDaysHours] = parseList(scanner: scanner, delimiter: ";"),
		   scanner.isAtEnd
		{
			return (result,nil)
		}
		return (nil,scanner.currentIndex)
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
