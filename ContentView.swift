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

// https://stackoverflow.com/questions/63079221/deleting-list-elements-from-swiftuis-list
struct SafeBinding<T: RandomAccessCollection & MutableCollection, C: View>: View {
	typealias BoundElement = Binding<T.Element>
	private let binding: BoundElement
	private let content: (BoundElement) -> C

	init(_ binding: Binding<T>, index: T.Index, @ViewBuilder content: @escaping (BoundElement) -> C) {
		self.content = content
		self.binding = .init(get: { binding.wrappedValue[index] },
							 set: { binding.wrappedValue[index] = $0 })
	}

	var body: some View {
		content(binding)
	}
}

// A formatter that does nothing.
// Necessary to force TextField to only send update events when editing completes,
// rather than on every keystroke
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
	var action:() -> Void

	var body: some View {
		Button(action: {
			action()
		})
		{
			Image(systemName: "trash")
				.font(.callout)
				.foregroundColor(.gray)
		}
	}
}

struct MonthDayPickerModal: View {
	@Binding var monthDay: MonthDay
	@Binding var isPresented: Bool
	@State private var temp: MonthDay

	init( monthDay: Binding<MonthDay>, isPresented: Binding<Bool>) {
		self._monthDay = monthDay
		self._isPresented = isPresented
		self._temp = State(initialValue: monthDay.wrappedValue)
	}

	private let dayCases:[Int?] = [nil,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,
								   16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31]

	var body: some View {

		VStack {

			HStack {
				Picker("", selection: $temp.month, content: { // <2>
					ForEach(Month.allCases, id:\.self) { month in
						Text(month.toString())
					}
				})
					.frame(width: 80)
					.clipped()

				Picker("", selection: $temp.day, content: { // <2>
					Text(" ")
					ForEach(dayCases, id:\.self) { day in
						Text(day == nil ? " " : "\(day!)")
					}
				})
					.frame(width: 80)
					.clipped()
			}

			Button(action: {
				isPresented = false
				monthDay = temp
			}, label: {
				Text("OK")
			})
		}
		.padding()
		.background(Color.white)
		.cornerRadius(20)
		.frame(maxWidth: .infinity,	maxHeight: .infinity)
		.background(Color.black.opacity(0.2))
		.ignoresSafeArea(edges: .all)
	}
}
struct MonthDayPicker: View {
	@Binding var binding : MonthDay

	@State private var showModalView: Bool = false

	var body: some View {
		Button(binding.toString(), action:{
			showModalView = true
		})
		.popover(isPresented: $showModalView, content: {
			MonthDayPickerModal(monthDay: $binding, isPresented: $showModalView)
		})
	}
}

struct MonthsView: View {
	@ObservedObject var openHours: OpenHours
	var group : MonthDayHours

	var body: some View {
		VStack {
			ForEach(group.months, id:\.self) { month in
				if let dayHoursIndex = openHours.groups.firstIndex(of: group),
				   let monthIndex = openHours.groups[dayHoursIndex].months.firstIndex(of: month)
				{
					HStack {
						Spacer()
						MonthDayPicker(binding: $openHours.groups[dayHoursIndex].months[monthIndex].begin)
							.font(.title)
						Text("-")
						MonthDayPicker(binding: $openHours.groups[dayHoursIndex].months[monthIndex].end)
							.font(.title)
						Spacer()
						TrashButton() {
							let dayHoursIndex = openHours.groups.firstIndex(of: group)!
							let monthIndex = openHours.groups[dayHoursIndex].months.firstIndex(of: month)!
							openHours.groups[dayHoursIndex].deleteMonthDayRange(at:monthIndex)
						}
					}
				}
			}
			Spacer()
			Button("More months", action: {
				let dayHoursIndex = openHours.groups.firstIndex(of: group)!
				openHours.groups[dayHoursIndex].addMonthDayRange()
			})
		}
	}
}

struct DaysOfWeekView: View {
	@ObservedObject var openHours: OpenHours
	var group: MonthDayHours

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
						let dayHoursIndex = openHours.groups.firstIndex(of: group)!
						openHours.groups[dayHoursIndex].toggleDay(day:day)
					})
					{
						Image(systemName: "checkmark")
							.padding(4)
							.background(group.daySet().count == 0 || group.daySet().contains(day) ? Color.blue : Color.gray.opacity(0.2))
							.clipShape(Circle())
							.font(.footnote)
							.foregroundColor(.white)
					}
				}
			}
			Spacer()
			if group.months.count == 0 && group.hours.count == 0 {
				TrashButton() {
					let dayHoursIndex = openHours.groups.firstIndex(of: group)!
					openHours.deleteMonthDayHours(at: dayHoursIndex)
				}
			}
		}
	}
}

struct HoursRowView: View {

	@Binding var date1 : Date
	@Binding var date2 : Date
	let deleteAction : () -> Void

	var body: some View {
		HStack {
			Spacer()
			DatePicker("",
					   selection:$date1,
					   displayedComponents:.hourAndMinute)
				.frame(width: 100)
			Text("-")
			DatePicker("",
					   selection:$date2,
					   displayedComponents:.hourAndMinute)
				.frame(width: 100)
			Spacer()
			TrashButton() {
				deleteAction()
			}
		}
	}
}

struct HoursView: View {
	@ObservedObject var openHours: OpenHours
	var group: MonthDayHours

	var body: some View {
		if let dayHoursIndex = openHours.groups.firstIndex(of: group) {

			VStack {
				ForEach(group.hours.indices, id:\.self) { hoursIndex in
					SafeBinding($openHours.groups[dayHoursIndex].hours, index: hoursIndex) { binding in
						HoursRowView(date1: binding.begin.asDate,
									 date2: binding.end.asDate,
									 deleteAction: {
										let dayHoursIndex = openHours.groups.firstIndex(of: group)
										openHours.groups[dayHoursIndex!].deleteHoursRange(at: hoursIndex)
									 })
					}
				}
				Button("More hours", action: {
					let dayHoursIndex = openHours.groups.firstIndex(of: group)
					openHours.groups[dayHoursIndex!].addHoursRange()
				})
			}
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
			ForEach(dateRanges.groups, id: \.self) { group in
				VStack {
					// months
					MonthsView(openHours: dateRanges, group: group)
					Spacer()

					// days
					DaysOfWeekView(openHours: dateRanges, group: group)

					// Hours
					HoursView(openHours:dateRanges, group:group)
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
