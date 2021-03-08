//
//  ContentView.swift
//  Shared
//
//  Created by Bryce Cogswell on 3/3/21.
//

import SwiftUI

extension View {
	func Print(_ vars: Any...) -> some View {
		for v in vars { print(v) }
		return EmptyView()
	}
}

class NoFormatter : Formatter {
	override func string(for obj: Any?) -> String? {
		return obj as? String
	}
	override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
		obj?.pointee = string as AnyObject
		return true
	}
}

struct TrashButton: View {
	var onPress:() -> Void

	var body: some View {
		Button(action: {
			onPress()
		})
		{
			Image(systemName: "trash")
				.font(.callout)
				.foregroundColor(.gray)
		}
	}
}

struct MonthsView: View {
	@ObservedObject var dateRanges: OpenHours
	var dayHours : MonthDayHours

	var body: some View {
		VStack {
			ForEach(dayHours.months, id:\.self) { month in
				HStack {
					Spacer()
					Button(month.toString(), action: {

					})
						.font(.title)
					Spacer()
					TrashButton() {
						let dayHoursIndex = dateRanges.list.firstIndex(of: dayHours)
						let monthIndex = dateRanges.list[dayHoursIndex!].months.firstIndex(of: month)
						dateRanges.list[dayHoursIndex!].deleteMonthDayRange(at:monthIndex!)
					}
				}
				/*
				HStack {
					Picker(selection: $selectedGenere, label: Text(month.toString())) {
						ForEach(0..<12) {
							Text("\($0)")
						}
					}
					.frame(width: 50)
					.clipped()
					Text(":")
					Picker(selection: $selectedGenere, label: Text(hours.begin.toString())) {
						ForEach(0..<12) {
							Text("\(5*$0)")
						}
					}
					.frame(width: 50,height:50)
						.clipped()
					Text("-")
					DatePicker("",selection:$dateRanges.list[dayHoursIndex].hours[hoursIndex].end.asDate, displayedComponents:.hourAndMinute)
					Spacer()
					Button(action: {
						dateRanges.list[dayHoursIndex].deleteHoursRange(at: hoursIndex)
					})
					{
						Image(systemName: "trash")
							.font(.callout)
							.foregroundColor(.gray)
					}
				}
	*/
			}
			Spacer()
			Button("More months", action: {
				let dayHoursIndex = dateRanges.list.firstIndex(of: dayHours)
				dateRanges.list[dayHoursIndex!].addMonthDayRange()
			})
		}
	}
}

struct DaysView: View {
	@ObservedObject var dateRanges: OpenHours
	var dayHours: MonthDayHours

	let days = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]

	var body: some View {
		// days
		HStack {
			Spacer()
			ForEach(days.indices, id: \.self) { day in
				VStack {
					Text(days[day])
						.font(.footnote)
					Button(action: {
						let dayHoursIndex = dateRanges.list.firstIndex(of: dayHours)
						dateRanges.list[dayHoursIndex!].toggleDay(day:day)
					})
					{
						Image(systemName: "checkmark")
							.padding(4)
							.background(dayHours.daySet().count == 0 || dayHours.daySet().contains(day) ? Color.blue : Color.gray.opacity(0.2))
							.clipShape(Circle())
							.font(.footnote)
							.foregroundColor(.white)
					}
				}
			}
			Spacer()
			if dayHours.months.count == 0 && dayHours.hours.count == 0 {
				TrashButton() {
					let dayHoursIndex = dateRanges.list.firstIndex(of: dayHours)
					dateRanges.deleteMonthDayHours(at: dayHoursIndex!)
				}
			}
		}
	}
}

struct HoursView: View {
	@ObservedObject var dateRanges: OpenHours
	var dayHours: MonthDayHours

	var body: some View {
		let dayHoursIndex = dateRanges.list.firstIndex(of: dayHours)

		VStack {
			ForEach(dayHours.hours.indices, id:\.self) { hoursIndex in
				let hours = dayHours.hours[hoursIndex]

				HStack {
#if false
					Spacer()
					Button(hours.toString(), action: {
					})
						.font(.title)
#else
					DatePicker("",
							   selection:$dateRanges.list[dayHoursIndex!].hours[hoursIndex].begin.asDate,
							   displayedComponents:.hourAndMinute)
						.frame(width: 100)
					Text("-")
DatePicker("",selection:$dateRanges.list[dayHoursIndex!].hours[hoursIndex].end.asDate,
							   displayedComponents:.hourAndMinute)
						.frame(width: 100)
#endif
					Spacer()
					TrashButton() {
						let dayHoursIndex = dateRanges.list.firstIndex(of: dayHours)
						dateRanges.list[dayHoursIndex!].deleteHoursRange(at: hoursIndex)
					}
				}
			}
			Button("More hours", action: {
				let dayHoursIndex = dateRanges.list.firstIndex(of: dayHours)
				dateRanges.list[dayHoursIndex!].addHoursRange()
			})
		}
	}
}

struct ContentView: View {

	@ObservedObject var dateRanges = OpenHours.init(fromString:"""
			Nov-Dec,Jan-Mar 05:30-23:30; \
			Apr-Oct Mo-Sa 05:00-24:00; \
			Apr-Oct Su 01:00-2:00,05:00-24:00
			""")
	let formatter = NoFormatter()

	@State private var currentDate = Date()
	@State private var showsDatePicker = false

    var body: some View {
		ScrollView {
			TextField("opening_hours", value: $dateRanges.string, formatter: formatter)
				.textFieldStyle(RoundedBorderTextFieldStyle())
			ForEach(dateRanges.list, id: \.self) { dayHours in
				VStack {
					// months
					MonthsView(dateRanges: dateRanges, dayHours: dayHours)
					Spacer()

					// days
					DaysView(dateRanges: dateRanges, dayHours: dayHours)

					// Hours
					HoursView(dateRanges:dateRanges, dayHours:dayHours)
				}
				.padding()
			}
			.padding()
			Button("More days", action: {
				dateRanges.addMonthDayHours()
			})
		}
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
