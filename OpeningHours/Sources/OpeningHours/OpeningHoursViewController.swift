//
//  File.swift
//  
//
//  Created by Bryce Cogswell on 3/23/21.
//

import SwiftUI

public class OpeningHoursViewController: UIHostingController<OpeningHoursView> {

	init(string: Binding<String>) {
		super.init(rootView: OpeningHoursView(string: string))
	}

	@objc required dynamic init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
