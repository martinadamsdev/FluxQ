//
//  Item.swift
//  FluxQ
//
//  Created by martinadamsdev on 2026/2/13.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
