//
//  TagInfo.swift
//  OpeningHours (iOS)
//
//  Created by Bryce Cogswell on 3/5/21.
//

import Foundation

public class TagInfoValues {

	public var values = [String]()

	public init() {
		self.restore()

		#if false
		repeat {
			let s = "Fr-Su 17-23"
			let v = OpeningHours.init(fromString: s)
			v.printErrorMessage()
		} while true
		#endif

		var badCnt = 0
		for index in self.values.indices {
			let value = self.values[index]

			let hours = OpeningHours(string: value)

			if hours.ruleList.rules.count == 0 {
				print("\(index):")
				hours.printErrorMessage()
				badCnt += 1
				for _ in 1...10 {
					hours.string = value
				}
				print("")
				continue
			}
			let s = hours.toString()
			let unSpaced1 = value.replacingOccurrences(of: ";", with: ",").replacingOccurrences(of: ", ", with: ",").replacingOccurrences(of: " ", with: "")
			let unSpaced2 = s.replacingOccurrences(of: ";", with: ",").replacingOccurrences(of: ", ", with: ",").replacingOccurrences(of: " ", with: "")
			if false && unSpaced1 != unSpaced2 {
				print("\(value)")
				print("\(s)")
				print("")
			}
		}
		let total = Double(self.values.count)
		let bad = Double(badCnt)
		print("Parses \(100*(total-bad)/total)% of \(total) strings, \(100*bad/total)% failing")
	}

	func save() {
		let encoder = JSONEncoder()
		do {
			let jsonData = try encoder.encode(values)
			let url = URL(fileURLWithPath: "/Users/bryce/Downloads/opening_hours.json")
			try jsonData.write(to: url)
		} catch {
			print("error")
		}
	}

	func restore() {
		do {
			if let url = Bundle.module.url(forResource: "opening_hours", withExtension:"txt") {
				let text = try String(contentsOf: url, encoding: .utf8)
				self.values = text.components(separatedBy: .newlines)
			} else {
				print("error")
			}
		} catch {
			print("error")
		}
	}

	// search the taginfo database, return the data immediately if its cached,
	// and call the update function later if it isn't
	func taginfoFor( key:String, update:@escaping (() -> Void)) -> Void
	{
		var rawData: Data? = nil
		let url = URL(fileURLWithPath: "/Users/bryce/Downloads/values.json")
		do {
			try rawData = Data(contentsOf: url)
		} catch {}
		if let rawData = rawData {
			var json: [AnyHashable : Any]? = nil
			do {
				json = try JSONSerialization.jsonObject(with: rawData, options: []) as? [AnyHashable : Any]
			} catch {
			}
			let results = json?["data"] as? [AnyHashable] ?? []
			var resultList: [String] = []
			for row in results {
				guard let row = row as? [AnyHashable : Any] else {
					continue
				}
				if let text = row["value"] as? String {
					resultList.append(text)
				}
			}
			DispatchQueue.main.async(execute: {
				self.values = resultList
				update()
			})
		}
	}
}
