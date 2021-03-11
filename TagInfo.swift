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

		var sentinel:String? = nil // Nov-Dec,Jan-Mar 05:30-23:30; Apr-Oct Mo-Sa 05:00-24:00; Apr-Oct Su 05:00-24:00"
		#if false
		repeat {
			let v = OpenHours.init(fromString: sentinel!)
			print("\"\(v?.toString() ?? "")\"")
		} while true
		#endif

		for index in self.values.indices {
			let value = self.values[index]

			if sentinel != nil && value != sentinel! {
				continue
			}
			sentinel = nil
			let dayHours = OpenHours(fromString: value)
			if dayHours.groups.count == 0 {
				print("\(value)")
				_ = OpenHours(fromString: value)
				continue
			}
			let s = dayHours.toString()
			let unSpaced1 = value.replacingOccurrences(of: ";", with: ",").replacingOccurrences(of: ", ", with: ",")
			let unSpaced2 = value.replacingOccurrences(of: ";", with: ",").replacingOccurrences(of: ", ", with: ",")
			if unSpaced1 != unSpaced2 {
				print("\(value) --> \(s)")
				_ = OpenHours(fromString: value)
				_ = dayHours.toString()
			}
		}
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
