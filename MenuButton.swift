//
//  MenuButton.swift
//  videoeditorApp
//
//  Created by macbook on 10/07/25.
//

import SwiftUI

struct MenuButton: View {
    let icon: String
    
    var body: some View {
        Button(action: {
            // Handle menu button action
        }) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.6))
                .cornerRadius(20)
        }
    }
}
