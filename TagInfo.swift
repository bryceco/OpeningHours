//
//  TagInfo.swift
//  OpeningHours (iOS)
//
//  Created by Bryce Cogswell on 3/5/21.
//

import Foundation

class TagInfo : Codable {

	public var values = [String]()

	init() {
		self.restore()

		#if false
		repeat {
			let s = "Apr 1-Oct 31: \"needs reservation by phone or web\""
			let v = OpenHours.init(fromString: s)
			v.printErrorMessage()
		} while true
		#endif

		var badCnt = 0
		for index in self.values.indices {
			let value = self.values[index]

			let hours = OpenHours(fromString: value)
			if hours.groups.count == 0 {
				print("\(index):")
				hours.printErrorMessage()
				badCnt += 1
				for _ in 1...10 {
					_ = OpenHours(fromString: value)
				}
				continue
			}
			let s = hours.toString()
			let unSpaced1 = value.replacingOccurrences(of: ";", with: ",").replacingOccurrences(of: ", ", with: ",")
			let unSpaced2 = value.replacingOccurrences(of: ";", with: ",").replacingOccurrences(of: ", ", with: ",")
			if unSpaced1 != unSpaced2 {
				print("\(index): \(value) --> \(s)")
				_ = OpenHours(fromString: value)
				_ = hours.toString()
			}
		}
		print("bad percentage = \(100.0*Double(badCnt)/Double(self.values.count))")
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
		let decoder = JSONDecoder()
		do {
			if let url = Bundle.main.url(forResource: "opening_hours", withExtension:"json") {
				let jsonData = try Data(contentsOf: url)
				self.values = try decoder.decode([String].self, from: jsonData)
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
