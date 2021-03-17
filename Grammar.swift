//
//  Grammar.swift
//  OpeningHours
//
//  Created by Bryce Cogswell on 3/17/21.
//

import Foundation

// Attempt to base parsing on the grammar defined at
// https://wiki.openstreetmap.org/wiki/Key:opening_hours/specification

/*
struct TimeDomain: Scannable {
	var list: [RuleSequence]
	static func scan(scanner: Scanner) -> TimeDomain? {
		if let first = RuleSequence.scan(scanner: scanner) {
			var list = [first]
			while let _ = AnyRuleSeperator.scan(scanner: scanner) {
				if let next = RuleSequence.scan(scanner: scanner) {
					list.append(next)
				} else {
					return nil
				}
			}
			return TimeDomain(list: list)
		}
		return nil
	}
}

struct AnyRuleSeperator: Scannable {
	let seperator:String
	static func scan(scanner: Scanner) -> AnyRuleSeperator? {
		if scanner.scanString(";") != nil {
			return AnyRuleSeperator(seperator: ";")
		}
		if scanner.scanString(",") != nil {
			return AnyRuleSeperator(seperator: ";")
		}
		if scanner.scanString("||") != nil {
			return AnyRuleSeperator(seperator: ";")
		}
		return nil
	}
}

struct RuleSequence: Scannable {
	let ss: SelectorSequence
	let rm: RuleModifier

	static func scan(scanner: Scanner) -> RuleSequence? {
		if let ss = SelectorSequence.scan(scanner: scanner),
		   let rm = RuleModifier.scan(scanner: scanner)
		{
			return RuleSequence(ss: ss, rm: rm)
		}
		return nil
	}
}

struct SelectorSequence: Scannable {
	let wr: WideRangeSelectors
	let sr: SmallRangeSelectors

	static func scan(scanner: Scanner) -> SelectorSequence? {
		if let _ = scanner.scanString("24/7") {
		} else if let wr = WideRangeSelectors.scan(scanner: scanner),
				  let sr = SmallRangeSelectors.scan(scanner: scanner)
		{
			return SelectorSequence(wr: wr, sr: sr)
		}
		return nil
	}

}

struct WideRangeSelectors: Scannable {
	let ys: YearSelector?
	let mds: MonthDaySelector?
	let ws: WeekSelector?
	let read: SeparatorForReadability?
	static func scan(scanner: Scanner) -> WideRangeSelectors? {
		return WideRangeSelectors(ys: YearSelector.scan(scanner: scanner),
								  mds: MonthDaySelector.scan(scanner: scanner),
								  ws: WeekSelector.scan(scanner: scanner),
								  read: SeparatorForReadability.scan(scanner: scanner))
	}
}
struct YearSelector: Scannable {
	var list: [YearRange]
	static func scan(scanner: Scanner) -> YearSelector? {
		if let list:[YearRange] = parseList(scanner: scanner, delimiter: ",") {
			return YearSelector(list: list)
		}
		return nil
	}
}
struct YearRange: Scannable {
	let yearBegin: Year
	let yearEnd: Year?
	let slash: Int?

	static func scan(scanner: Scanner) -> YearRange? {
		if let y1 = Year.scan(scanner: scanner) {
			if scanner.scanString("+") != nil {
				return YearRange(yearBegin: y1, yearEnd: nil, slash: nil)
			}
			if scanner.scanString("-") != nil,
			   let y2 = Year.scan(scanner: scanner)
			{
				if scanner.scanString("/") != nil,
				   let pn = scanner.scanInt()
				{
					return YearRange(yearBegin: y1, yearEnd: y2, slash: pn)
				}
				return YearRange(yearBegin: y1, yearEnd: y2, slash: nil)
			}
			return nil
		}
		return nil
	}
}
struct Year: Scannable {
	let value: Int
	static func scan(scanner: Scanner) -> Year? {
		if let n = scanner.scanInt(),
		   n >= 1900
		{
			return Year(value: n)
		}
		return nil
	}
}

struct MonthDaySelector: Scannable {
	let list: [MonthDay_Range]
	static func scan(scanner: Scanner) -> MonthDaySelector? {
		if let list:[MonthDay_Range] = parseList(scanner: scanner, delimiter: ",") {
			return MonthDaySelector(list:list)
		}
		return nil
	}
}
struct MonthDay_Range: Scannable {
	let range: DateFrom
	static func scan(scanner: Scanner) -> MonthDay_Range? {
		if let range = DateFrom.scan(scanner: scanner) {
			if let offset1 = DateOffset.scan(scanner: scanner) {
				if scanner.scanString("")
			}
		}
		let year = Year.scan(scanner: scanner)
		if let month1 = Month.scan(scanner: scanner) {
			if scanner.scanString("-") != nil,
			   let month2 = Month.scan(scanner: scanner)
			{

			}
		}
		return nil
	}
}
enum MonthDate {
	case monthday(Month,Day)
	case namedDate(String)
}
struct DateFrom: Scannable {
	let year: Year?
	let monthDate: MonthDate

	static func scan(scanner: Scanner) -> DateFrom? {
		let index = scanner.currentIndex
		let year = Year.scan(scanner: scanner)
		if let month = Month.scan(scanner: scanner),
		   let day = Day.scan(scanner: scanner)
		{
			return DateFrom(year: year,monthDate: MonthDate.monthday(month, day))
		}
		scanner.currentIndex = index
		return nil
	}
}
struct DateOffset: Scannable {

	static func scan(scanner: Scanner) -> DateOffset? {
		let index = scanner.currentIndex
		if let plusMinus = scanner.scanString("+") ?? scanner.scanString("-"),
		   let wday = Day.scan(scanner: scanner)
		{

		}
		scanner.currentIndex = index

		[ <plus_or_minus> <wday> ] [ <day_offset> ]
	}
}
struct DayOffset: Scanner {
	static func scan(scanner: Scanner) -> DayOffset? {

	<space> <plus_or_minus> <positive_number> <space> day[s]
	}
}
struct WeekSelector: Scannable {
	static func scan(scanner: Scanner) -> WeekSelector? {
	}
}
struct SeparatorForReadability {
	static func scan(scanner: Scanner) -> SeparatorForReadability? {
	}
}

struct SmallRangeSelectors: Scannable {
	static func scan(scanner: Scanner) -> SmallRangeSelectors? {
	}
}

struct RuleModifier {
	static func scan(scanner: Scanner) -> RuleModifier? {
	}
}
*/
