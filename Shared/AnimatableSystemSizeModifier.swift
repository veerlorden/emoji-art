//
//  AnimatableSystemSizeModifier.swift
//  EmojiArt
//
//  Created by Вадим Буркин on 01.09.2021.
//

import SwiftUI

struct AnimatableSystemSizeModifier: AnimatableModifier {
    var size: CGFloat
    
    var animatableData: CGFloat {
        get { size }
        set { size = newValue }
    }
    
    func body(content: Content) -> some View {
        content.font(.system(size: size))
    }
}

extension View {
    func animatableFont(size: CGFloat) -> some View {
        self.modifier(AnimatableSystemSizeModifier(size: size))
    }
}
