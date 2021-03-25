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

class OpeningHoursBinding: OpeningHours {

	var binding: Binding<String>

	public init(binding: Binding<String>) {
		self.binding = binding
		super.init()
		self.string = binding.wrappedValue
	}

	override var ruleList : RuleList {
		get {
			return super.ruleList
		}
		set {
			super.ruleList = newValue
			DispatchQueue.main.async { self.binding.wrappedValue = self.string }
		}
	}
}
