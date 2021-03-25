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

	override var ruleList : RuleList {
		get {
			return super.ruleList
		}
		set {
			super.ruleList = newValue
			if let binding = binding {
				DispatchQueue.main.async {	binding.wrappedValue = self.string }
			}
		}
	}

	var binding: Binding<String>?

	public convenience init(binding:Binding<String>) {
		self.init()
		self.binding = binding
		self.string = binding.wrappedValue
	}
}
