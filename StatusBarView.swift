//
//  StatusBarView.swift
//  videoeditorApp
//
//  Created by macbook on 10/07/25.
//

import SwiftUI

struct StatusBarView: View {
    var body: some View {
        HStack {
            Text("9:41")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            HStack(spacing: 5) {
                Image(systemName: "signal.bars.3")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                
                Image(systemName: "wifi")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                
                Image(systemName: "battery.100")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.black)
    }
}
