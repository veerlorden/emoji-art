//
//  EmojiArtApp.swift
//  Shared
//
//  Created by Вадим Буркин on 21.09.2021.
//

import SwiftUI

@main
struct EmojiArtApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: EmojiArtDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
