//
//  MessageListView.swift
//  FluxQWatch
//
//  Created by martinadamsdev on 2026/2/13.
//

import SwiftUI

struct MessageListView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "message.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text("暂无消息")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("FluxQ")
        }
    }
}

#Preview {
    MessageListView()
}
