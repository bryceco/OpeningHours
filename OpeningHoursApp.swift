//
//  OpeningHoursApp.swift
//  Shared
//
//  Created by Bryce Cogswell on 3/3/21.
//

import SwiftUI
import OpeningHours

@main
struct OpeningHoursApp: App {

	// let tagInfo = TagInfoValues()

	@State var opening_hours = """
			Nov-Dec,Jan-Mar 05:30-23:30; \
			Apr-Oct Mo-Sa 05:00-24:00; \
			Apr-Oct Su 01:00-2:00,05:00-24:00
			"""

    var body: some Scene {
        WindowGroup {
			VStack {
				Text(opening_hours)
				OpeningHoursView(string: $opening_hours)
			}
		}
    }
}
