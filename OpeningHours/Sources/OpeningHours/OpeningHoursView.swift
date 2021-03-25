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



struct HourPickerModal: View {
	@Binding var hour: Hour
	@Binding var isPresented: Bool
	@State private var temp: Hour

	init( hour: Binding<Hour>, isPresented: Binding<Bool>) {
		self._hour = hour
		self._isPresented = isPresented
		self._temp = State(initialValue: hour.wrappedValue)
	}

	var body: some View {

		VStack {

			HStack {
				// type of time: "12:45" or "sunrise"
				Picker("", selection: $temp.typeBinding, content: { // <2>
					ForEach(Hour.allCases.indices, id:\.self) { typeIndex in
						let type = Hour.allCases[typeIndex]
						Text(typeIndex == 0 ? "time of day" : type.toString())
					}
				})
				.frame(width: 120)
				.clipped()

				if temp.isTime() {
					Picker("", selection: $temp.hourBinding, content: { // <2>
						ForEach(0...24, id:\.self) { hour in
							Text("\(String(format: "%02d", hour))")
						}
					})
					.frame(width: 80)
					.clipped()

					Text(":")

					Picker("", selection: $temp.minuteBinding, content: { // <2>
						ForEach(0...11, id:\.self) { minute in
							Text("\(String(format: "%02d", 5*minute))")
						}
					})
					.frame(width: 80)
					.clipped()
				}
			}

			Button(action: {
				isPresented = false
				hour = temp
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
struct HourPickerButton: View {
	@Binding var binding : Hour

	@State private var showModalView: Bool = false

	var body: some View {
		Button(binding.toString(), action:{
			showModalView = true
		})
		.popover(isPresented: $showModalView, content: {
			HourPickerModal(hour: $binding, isPresented: $showModalView)
		})
	}
}


struct MonthDayPickerModal: View {
	@Binding var monthDay: DayOfYear
	@Binding var isPresented: Bool
	@State private var temp: DayOfYear

	init( monthDay: Binding<DayOfYear>, isPresented: Binding<Bool>) {
		self._monthDay = monthDay
		self._isPresented = isPresented
		self._temp = State(initialValue: monthDay.wrappedValue)
	}

	private let dayCases = [nil] + Array(1...31).map { Day($0) }

	var body: some View {

		VStack {

			HStack {
				let dayList = temp.dayList()

				Picker("", selection: $temp.typeBinding, content: {
					ForEach(DayOfYear.allTypes.indices, id:\.self) { typeIndex in
						Text(DayOfYear.allTypes[typeIndex])
					}
				})
				.frame(width: 80)
				.clipped()

				Picker("", selection: $temp.monthBinding, content: {
					let list = temp.monthList()
					ForEach(list.indices, id:\.self) { monthIndex in
						let text = list[monthIndex]
						let text2 = text.prefix(1).capitalized + text.dropFirst()
						Text(text2)
					}
				})
				.frame(width: 80)
				.clipped()

				if dayList.count > 0 {
					Picker("", selection: $temp.dayBinding, content: {
						ForEach(dayList.indices, id:\.self) { dayIndex in
							Text(dayList[dayIndex])
						}
					})
					.frame(width: 80)
					.clipped()
				}
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
	@Binding var binding : DayOfYear

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
							.background(daysHours.weekdaysSet().count == 0 || daysHours.weekdaysSet().contains(day) ? Color.blue : Color.gray.opacity(0.2))
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

	@Binding var date1 : Hour
	@Binding var date2 : Hour
	let deleteAction : () -> Void

	var body: some View {
		HStack {
			Spacer()
			HourPickerButton(binding: $date1)
				.frame(width: 100)
			Text("-")
			HourPickerButton(binding: $date2)
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
					HoursRowView(date1: binding.begin,
								 date2: binding.end,
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

						if binding.wrappedValue.hours.count == 0 && group.months.count == 0 && group.daysHours.count == 1 {
							TrashButton() {
								groupList.removeAll(where: { $0 == group })
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


public struct OpeningHoursView: View {

	@Binding var string: String
	@ObservedObject var openingHours: OpeningHours

	public init( string: Binding<String> ) {
		self._string = string
		self.openingHours = OpeningHoursBinding(binding: string)
	}

	let formatter = NoFormatter()

	public var body: some View {
		ScrollView {
			TextField("opening_hours", value: $openingHours.string, formatter: formatter)
				.textFieldStyle(RoundedBorderTextFieldStyle())
			ForEach(openingHours.ruleList.rules.indices, id: \.self) { groupIndex in
				SafeBinding($openingHours.ruleList.rules, index: groupIndex) { group in
					MonthsDaysHoursView(groupList: $openingHours.ruleList.rules, group: group)
					.padding()
				}
			}
			.padding()
			Button("More ranges", action: {
				openingHours.addMonthDayHours()
			})
		}
    }
}

struct OpeningHoursView_Previews: PreviewProvider {

	static var previews: some View {
		Text("hello")
//		OpeningHoursView(string: .constant("Mo-Fr 6:00-18:00"))
    }
}
