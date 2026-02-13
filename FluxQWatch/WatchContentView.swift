//
//  WatchContentView.swift
//  FluxQWatch
//
//  Created by martinadamsdev on 2026/2/13.
//

import SwiftUI

struct WatchContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "message.fill")
                .font(.largeTitle)
            Text("FluxQ")
                .font(.headline)
        }
    }
}

#Preview {
    WatchContentView()
}
