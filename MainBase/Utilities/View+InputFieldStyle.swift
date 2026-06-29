import SwiftUI

extension View {
    func inputFieldStyle(background: Color = AppColors.cardBackground) -> some View {
        self
            .font(.system(size: 16))
            .foregroundColor(AppColors.text)
            .frame(height: 50)
            .padding(.horizontal, 16)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))
    }
}
