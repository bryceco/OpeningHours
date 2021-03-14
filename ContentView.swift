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
struct MonthDayPickerButton: View {
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
	@Binding var monthsList: [MonthDayRange]

	var body: some View {

		VStack {
			ForEach(monthsList.indices, id:\.self) { monthIndex in
				SafeBinding($monthsList, index:monthIndex) { month in
					HStack {
						Spacer()
						MonthDayPickerButton(binding: month.begin)
							.font(.title)
						Text("-")
						MonthDayPickerButton(binding: month.end)
							.font(.title)
						Spacer()
						TrashButton() {
							monthsList.remove(at: monthIndex)
						}
					}
				}
			}
			Spacer()
			Button("More months", action: {
				monthsList.append(MonthDayRange.defaultValue)
			})
			.padding( [.top,.bottom], 10.0 )
		}
	}
}

struct DaysOfWeekRowView: View {
	@Binding var daysHoursList: [DaysHours]
	@Binding var daysHours: DaysHours

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
						daysHours.toggleDay(day:day)
					})
					{
						Image(systemName: "checkmark")
							.padding(4)
							.background(daysHours.daySet().count == 0 || daysHours.daySet().contains(day) ? Color.blue : Color.gray.opacity(0.2))
							.clipShape(Circle())
							.font(.footnote)
							.foregroundColor(.white)
					}
				}
			}
			Spacer()
			if daysHours.hours.count == 0 && daysHoursList.count > 1 {
				TrashButton() {
					let index = daysHoursList.firstIndex(of: daysHours)!
					daysHoursList.remove(at: index)
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
	@Binding var daysHours: DaysHours

	var body: some View {

		VStack {
			ForEach(daysHours.hours.indices, id:\.self) { hoursIndex in
				SafeBinding($daysHours.hours, index: hoursIndex) { binding in
					HoursRowView(date1: binding.begin.asDate,
								 date2: binding.end.asDate,
								 deleteAction: {
									daysHours.deleteHoursRange(at: hoursIndex)
								 })
				}
			}
			Button("More hours", action: {
				daysHours.addHoursRange()
			})
			.padding()
		}
	}
}

struct DaysHoursView: View {
	@Binding var groupList: [MonthsDaysHours]
	@Binding var group: MonthsDaysHours

	var body: some View {

		VStack {
			ForEach(group.daysHours.indices, id:\.self) { daysHoursIndex in

				SafeBinding($group.daysHours, index: daysHoursIndex) { binding in
					HStack {
						DaysOfWeekRowView(daysHoursList: $group.daysHours, daysHours: binding)

						if binding.wrappedValue.hours.count == 0 && group.months.count == 0 {
							TrashButton() {
								groupList.remove(at: daysHoursIndex)
							}
						}
					}

					HoursView(daysHours: binding)
				}
			}
			Button("More days/hours", action: {
				group.addDaysHours()
			})
		}
	}
}

struct MonthsDaysHoursView: View {
	@Binding var groupList: [MonthsDaysHours]
	@Binding var group: MonthsDaysHours

	var body: some View {
		VStack {
			// months
			MonthsView(monthsList: $group.months)
			Spacer()

			// days/hours
			DaysHoursView(groupList: $groupList, group: $group)
		}
		.padding()
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
			ForEach(dateRanges.groups.indices, id: \.self) { groupIndex in
				SafeBinding($dateRanges.groups, index: groupIndex) { group in
					MonthsDaysHoursView(groupList: $dateRanges.groups, group: group)
					.padding()
				}
			}
			.padding()
			Button("More ranges", action: {
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
