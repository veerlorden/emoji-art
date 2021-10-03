# EmojiArt 🎨

#### A multi-platform app based on Stanford's CS193p course on SwiftUI (Spring 2021)

## About the App
Drag various backgrounds and emojis on to the canvas to create artworks. Available on three platforms: iPad, iPhone and Mac. 

## Technologies
- Swift
- SwiftUI
- MVVM
- SwiftUI's integration with UIKit
- Multiplatform: iPhone, iPad, Mac
- Gestures
- Drag&Drop
- UndoManager
- URLSession
- GCD

## Screenshots
<div align="center">
    <img style="width: 25%;" src="https://github.com/veerlorden/emoji-art/blob/main/Screenshots/documentview-1.png" alt="document-view">
    <img style="width: 25%;" src="https://github.com/veerlorden/emoji-art/blob/main/Screenshots/imagepicker.png" alt="image-picker">
    <img style="width: 25%;" src="https://github.com/veerlorden/emoji-art/blob/main/Screenshots/palette-manager.png" alt="palette-manager">
</div>
<div align="center">
    <img style="width: 40%;" src="https://github.com/veerlorden/emoji-art/blob/main/Screenshots/mainscreen-editor.png" alt="main-screen-editor">
    <img style="width: 40%;" src="https://github.com/veerlorden/emoji-art/blob/main/Screenshots/mainscreen.png" alt="main-screen">
</div>

## Sample Code
```swift
class EmojiArtDocument: ReferenceFileDocument
{
    static var readableContentTypes = [UTType.emojiart]
    static var writeableContentTypes = [UTType.emojiart]
    
    required init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            emojiArt = try EmojiArtModel(json: data)
            fetchBackgroundImageDataIfNecessary()
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }
    
    func snapshot(contentType: UTType) throws -> Data {
        return try emojiArt.json()
    }
    
    func fileWrapper(snapshot: Data, configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: snapshot)
    }
    
    @Published private(set) var emojiArt: EmojiArtModel {
        didSet {
            if emojiArt.background != oldValue.background {
                fetchBackgroundImageDataIfNecessary()
            }
        }
    }
    
    init() {
        emojiArt = EmojiArtModel()
    }
    
    var emojis: [EmojiArtModel.Emoji] { emojiArt.emojis }
    var background: EmojiArtModel.Background { emojiArt.background }
    
    @Published var backgroundImage: UIImage?
    @Published var backgroundImageFetchStatus = BackgroundImageFetchStatus.idle
    
    enum BackgroundImageFetchStatus: Equatable {
        case idle
        case fetching
        case failed(URL)
    }
    
    private var backgroundImageFetchCancellable: AnyCancellable?
    
    private func fetchBackgroundImageDataIfNecessary() {
        backgroundImage = nil
        switch emojiArt.background {
        case .url(let url):
            // fetch the url
            backgroundImageFetchStatus = .fetching
            backgroundImageFetchCancellable?.cancel()
            let session = URLSession.shared
            let publisher = session.dataTaskPublisher(for: url)
                .map { (data, urlResponse) in UIImage(data: data) }
                .replaceError(with: nil)
                .receive(on: DispatchQueue.main)
            backgroundImageFetchCancellable = publisher
                .sink { [weak self] image in
                    self?.backgroundImage = image
                    self?.backgroundImageFetchStatus = (image != nil) ? .idle : .failed(url)
                }
        case .imageData(let data):
            backgroundImage = UIImage(data: data)
        case .blank:
            break
        }
    }
}
```

## Credits
#### [Stanford University's course CS193p (Developing Applications for iOS using SwiftUI)](https://cs193p.sites.stanford.edu)
