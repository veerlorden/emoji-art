//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by Вадим Буркин on 22.08.2021.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    typealias Emoji = EmojiArtModel.Emoji
    
    @ObservedObject var document: EmojiArtDocument
    @Environment(\.undoManager) var undoManager
    @ScaledMetric var defaultEmojiFontSize: CGFloat = 40
    
    var body: some View {
        VStack(spacing: 0) {
            documentBody
            PaletteChooser(emojiFontSize: defaultEmojiFontSize)
        }
    }
    
    var documentBody: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                OptionalImage(uiImage: document.backgroundImage)
                    .scaleEffect(zoomScale)
                    .position(convertFromEmojiCoordinates((0,0), in: geometry))
                .gesture(doubleTapToZoom(in: geometry.size).exclusively(before: deselectEmojisGesture()))
                if document.backgroundImageFetchStatus == .fetching {
                    ProgressView().scaleEffect(2)
                } else {
                    ForEach(document.emojis) { emoji in
                        Text(emoji.text)
                            .animatableFont(size: fontSize(for: emoji))
                            .background(isEmojiSelected(emoji) ? selectedEmojiBackground : nil)
                            .position(position(for: emoji, in: geometry))
                            .gesture(selectEmojiGesture(emoji).simultaneously(with: dragEmojiGesture(in: geometry)))
                    }
                }
            }
            .clipped()
            .onDrop(of: [.utf8PlainText, .url, .image], isTargeted: nil) { providers, location in
                return drop(providers: providers, at: location, in: geometry)
            }
            .gesture(panGesture().simultaneously(with: zoomGesture()))
            .alert(item: $alertToShow) { alertToShow in
                alertToShow.alert()
            }
            .onChange(of: document.backgroundImageFetchStatus) { status in
                switch status {
                case .failed(let url):
                    showBackgroundImageFetchFailedAlert(url)
                default:
                    break
                }
            }
            .onReceive(document.$backgroundImage) { image in
                if autozoom {
                    zoomToFit(image, in: geometry.size)
                }
            }
            .compactableToolbar {
                AnimatedActionButton(title: "Paste Background", systemImage: "doc.on.clipboard") {
                    pasteBackground()
                }
                if Camera.isAvailable {
                    AnimatedActionButton(title: "Take Photo", systemImage: "camera") {
                        backgroundPicker = .camera
                    }
                }
                if PhotoLibrary.isAvailable {
                    AnimatedActionButton(title: "Seacrh Photos", systemImage: "photo") {
                        backgroundPicker = .library
                    }
                }
                if let undoManager = undoManager {
                    #if os(iOS)
                    if undoManager.canUndo {
                        AnimatedActionButton(title: undoManager.undoActionName, systemImage: "arrow.uturn.backward") {
                            undoManager.undo()
                        }
                    }
                    if undoManager.canRedo {
                        AnimatedActionButton(title: undoManager.redoActionName, systemImage: "arrow.uturn.forward") {
                            undoManager.redo()
                        }
                    }
                    #endif
                    if !selectedEmojis.isEmpty {
                        AnimatedActionButton(title: "Remove Selected Emojis", systemImage: "trash.fill") {
                            document.removeEmojis(selectedEmojis, undoManager: undoManager)
                            selectedEmojis = []
                        }
                    }
                }
            }
            .sheet(item: $backgroundPicker) { pickerType in
                switch pickerType {
                case .camera: Camera(handlePickedImage: { image in handlePickedBackgroundImage(image) })
                case .library: PhotoLibrary(handlePickedImage: { image in handlePickedBackgroundImage(image) })
                }
            }
        }
    }
    
    @State private var backgroundPicker: BackgroundPickerType?
    
    private func handlePickedBackgroundImage(_ image: UIImage?) {
        autozoom = true
        if let imageData = image?.imageData {
            document.setBackground(.imageData(imageData), undoManager: undoManager)
        }
        backgroundPicker = nil
    }
    
    enum BackgroundPickerType: Identifiable {
        case camera
        case library
        var id: BackgroundPickerType { self }
    }
    
    private func pasteBackground() {
        autozoom = true
        if let imageData = Pasteboard.imageData {
            document.setBackground(.imageData(imageData), undoManager: undoManager)
        } else if let url = Pasteboard.imageURL {
            document.setBackground(.url(url), undoManager: undoManager)
        } else {
            alertToShow = IdentifiableAlert(
                title: "Paste Background",
                message: "There is no image currently on the pasteboard.")
        }
    }
    
    @State private var autozoom = false
    
    @State private var alertToShow: IdentifiableAlert?
    
    func showBackgroundImageFetchFailedAlert(_ url: URL) {
        alertToShow = IdentifiableAlert(id: "fetch failed " + url.absoluteString) {
            Alert(
                title: Text("Background Image Fetch"),
                message: Text("Couldn't load image from \(url)"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Drag and Drop
    
    private func drop(providers: [NSItemProvider], at location: CGPoint, in geometry: GeometryProxy) -> Bool {
        var found = providers.loadObjects(ofType: URL.self) { url in
            autozoom = true
            document.setBackground(.url(url.imageURL), undoManager: undoManager)
        }
        #if os(iOS)
        if !found {
            found = providers.loadObjects(ofType: UIImage.self) { image in
                if let data = image.jpegData(compressionQuality: 1.0) {
                    autozoom = true
                    document.setBackground(.imageData(data), undoManager: undoManager)
                }
            }
        }
        #endif
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                if let emoji = string.first, emoji.isEmoji {
                    document.addEmoji(
                        String(emoji),
                        at: convertToEmojiCoordinates(location, in: geometry),
                        size: defaultEmojiFontSize / zoomScale,
                        undoManager: undoManager
                    )
                }
            }
        }
        
        return found
    }
    
    // MARK: - Selection
    
    @State private var selectedEmojis = Set<Emoji>()
    
    private func isEmojiSelected(_ emoji: Emoji) -> Bool {
        selectedEmojis.contains(where: { $0.id == emoji.id })
    }
    
    private func selectEmojiGesture(_ emoji: Emoji) -> some Gesture {
        TapGesture()
            .onEnded {
                withAnimation {
                    selectedEmojis.toggleMembership(of: emoji)
                }
            }
    }
    
    private var selectedEmojiBackground: some View {
        ZStack {
            Circle()
                .foregroundColor(Color.red)
                .scaleEffect(1.5)
                .opacity(0.7)
                .shadow(radius: 10)
        }
    }
    
    private func deselectEmojisGesture() -> some Gesture {
        TapGesture()
            .onEnded {
                withAnimation {
                    selectedEmojis = []
                }
            }
    }
    
    // MARK: - Panning/Dragging
    
    @GestureState private var gestureEmojiOffset = CGSize.zero
    
    private func dragEmojiGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .updating($gestureEmojiOffset) { latestDragGestureValue, gestureEmojiOffset, _ in
                gestureEmojiOffset = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                selectedEmojis.forEach { emoji in
                    document.moveEmoji(emoji, by: finalDragGestureValue.translation / zoomScale, undoManager: undoManager)
                }
            }
    }
    
    @SceneStorage("EmojiArtDocumentView.steadyStatePanOffset")
    private var steadyStatePanOffset = CGSize.zero
    @GestureState private var gesturePanOffset = CGSize.zero
    
    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, _ in
                gesturePanOffset = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                steadyStatePanOffset = steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
            }
    }
    
    // MARK: - Zooming
    
    @SceneStorage("EmojiArtDocumentView.steadyStateZoomScale")
    private var steadyStateZoomScale: CGFloat = 1
    @GestureState private var gestureZoomScale: CGFloat = 1
    @GestureState private var gestureEmojiZoomScale: CGFloat = 1
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    private func zoomGesture() -> some Gesture {
        if !selectedEmojis.isEmpty {
            return MagnificationGesture()
                .updating($gestureEmojiZoomScale) { latestGestureScale, gestureEmojiZoomScale, _ in
                    gestureEmojiZoomScale = latestGestureScale
                }
                .onEnded { gestureScaleAtEnd in
                    selectedEmojis.forEach { emoji in
                        document.scaleEmoji(emoji, by: gestureScaleAtEnd, undoManager: undoManager)
                    }
                }
        }
        
        return MagnificationGesture()
            .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, _ in
                gestureZoomScale = latestGestureScale
            }
            .onEnded { gestureScaleAtEnd in
                steadyStateZoomScale *= gestureScaleAtEnd
            }
    }
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    zoomToFit(document.backgroundImage, in: size)
                }
            }
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0 {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            steadyStatePanOffset = .zero
            steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
    // MARK: - Positioning/Sizing Emojis
    
    private func fontSize(for emoji: Emoji) -> CGFloat {
        let originalSize = CGFloat(emoji.size) * zoomScale
        return isEmojiSelected(emoji) ? originalSize * gestureEmojiZoomScale : originalSize
    }
    
    private func position(for emoji: Emoji, in geometry: GeometryProxy) -> CGPoint {
        var location = convertFromEmojiCoordinates((emoji.x, emoji.y), in: geometry)
        if isEmojiSelected(emoji) {
            location = CGPoint(x: location.x + gestureEmojiOffset.width, y: location.y + gestureEmojiOffset.height)
        }
        return location
    }
    
    private func convertFromEmojiCoordinates(_ location: (x: Int, y: Int), in geometry: GeometryProxy) -> CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint(
            x: center.x + CGFloat(location.x) * zoomScale + panOffset.width,
            y: center.y + CGFloat(location.y) * zoomScale + panOffset.height
        )
    }
    
    private func convertToEmojiCoordinates(_ location: CGPoint, in geometry: GeometryProxy) -> (x: Int, y: Int) {
        let center = geometry.frame(in: .local).center
        let location = CGPoint(
            x: (location.x - panOffset.width - center.x) / zoomScale,
            y: (location.y - panOffset.height - center.y) / zoomScale
        )
        
        return (Int(location.x), Int(location.y))
    }
}

// MARK: - Previews

struct EmojiArtDocumentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
            .environmentObject(PaletteStore(named: "Preview"))
    }
}
