import SwiftUI
import SpriteKit

@MainActor
struct PieceGlyph: View {
    let piece: VisualPiece

    var body: some View {
        Image(uiImage: PieceGlyphCache.image(for: piece))
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

@MainActor
private enum PieceGlyphCache {
    static var images: [VisualPiece: UIImage] = [:]

    static func image(for piece: VisualPiece) -> UIImage {
        if let cached = images[piece] { return cached }
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 128, height: 128))
        let node = SKNode()
        node.position = CGPoint(x: 64, y: 61)
        node.setScale(1.18)
        IslandArt.building(piece, on: node)
        let container = SKNode()
        container.addChild(node)
        let image: UIImage
        if let texture = view.texture(from: container, crop: CGRect(x: 0, y: 0, width: 128, height: 128)) {
            image = UIImage(cgImage: texture.cgImage())
        } else {
            image = UIImage(systemName: "square.fill") ?? UIImage()
        }
        images[piece] = image
        return image
    }
}
