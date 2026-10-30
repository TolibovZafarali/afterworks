import SpriteKit
import UIKit

struct GridPoint: Hashable, Identifiable {
    var row: Int
    var col: Int
    var id: Int { row * 7 + col }
}

enum VisualTerrain: String {
    case grass, stone, water, woodland, wetland, cliff
}

enum VisualPiece: String {
    case quarry, orchard, lumberCamp, field, reservoir, road, bridge, depot
}

struct BoardCellVisual: Equatable {
    var point: GridPoint
    var terrain: VisualTerrain
    var building: VisualPiece? = nil
    var infrastructure: VisualPiece? = nil
    var isInherited: Bool = false
    var isConnected: Bool? = nil
    var isSelected: Bool = false
    var placementAllowed: Bool? = nil
    var futureChanged: Bool = false
}

struct BoardSceneModel: Equatable {
    var cells: [BoardCellVisual]
    var isPreview: Bool = false
    var reduceMotion: Bool = false
}

enum DeliveryResource {
    case stone, food, timber
}

struct DeliveryVisual {
    var route: [GridPoint]
    var resource: DeliveryResource
}

enum IslandColors {
    static let ink = UIColor(hex: 0x344539)
    static let paper = UIColor(hex: 0xF4EEDC)
    static let sand = UIColor(hex: 0xD6C99D)
    static let grass = UIColor(hex: 0xB9C893)
    static let grassAlternate = UIColor(hex: 0xB3C48B)
    static let moss = UIColor(hex: 0x6C8755)
    static let darkMoss = UIColor(hex: 0x476546)
    static let leaf = UIColor(hex: 0x769857)
    static let lightLeaf = UIColor(hex: 0x94AE69)
    static let water = UIColor(hex: 0x83B2B5)
    static let deepWater = UIColor(hex: 0x66969D)
    static let wetland = UIColor(hex: 0x9CAC86)
    static let terracotta = UIColor(hex: 0xB96748)
    static let roofHighlight = UIColor(hex: 0xCD8057)
    static let brown = UIColor(hex: 0x836A49)
    static let stone = UIColor(hex: 0x9C9C87)
    static let stoneLight = UIColor(hex: 0xC6C4AE)
    static let road = UIColor(hex: 0xE9D9B6)
    static let oldRoad = UIColor(hex: 0xD5C49E)
    static let darkRoad = UIColor(hex: 0xB1A17C)
    static let shadow = UIColor(hex: 0x344539).withAlphaComponent(0.15)
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

enum IslandArt {
    @discardableResult
    static func ellipse(_ node: SKNode, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                        color: UIColor, z: CGFloat = 0) -> SKShapeNode {
        let shape = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
        shape.position = CGPoint(x: x, y: y)
        shape.fillColor = color
        shape.strokeColor = .clear
        shape.zPosition = z
        shape.isAntialiased = true
        node.addChild(shape)
        return shape
    }

    @discardableResult
    static func rect(_ node: SKNode, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                     radius: CGFloat = 0, color: UIColor, z: CGFloat = 0) -> SKShapeNode {
        let shape = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: radius)
        shape.position = CGPoint(x: x, y: y)
        shape.fillColor = color
        shape.strokeColor = .clear
        shape.zPosition = z
        shape.isAntialiased = true
        node.addChild(shape)
        return shape
    }

    @discardableResult
    static func polygon(_ node: SKNode, points: [CGPoint], color: UIColor,
                        stroke: UIColor = .clear, lineWidth: CGFloat = 1, z: CGFloat = 0) -> SKShapeNode {
        let path = CGMutablePath()
        if let first = points.first {
            path.move(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
            path.closeSubpath()
        }
        let shape = SKShapeNode(path: path)
        shape.fillColor = color
        shape.strokeColor = stroke
        shape.lineWidth = lineWidth
        shape.lineJoin = .round
        shape.zPosition = z
        node.addChild(shape)
        return shape
    }

    @discardableResult
    static func line(_ node: SKNode, points: [CGPoint], color: UIColor,
                     width: CGFloat, z: CGFloat = 0) -> SKShapeNode {
        let path = CGMutablePath()
        if let first = points.first {
            path.move(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
        }
        let shape = SKShapeNode(path: path)
        shape.strokeColor = color
        shape.lineWidth = width
        shape.lineCap = .round
        shape.lineJoin = .round
        shape.zPosition = z
        node.addChild(shape)
        return shape
    }

    static func tree(_ parent: SKNode, x: CGFloat, y: CGFloat, size: CGFloat, fruit: Bool = false, pine: Bool = false) {
        let tree = SKNode()
        tree.position = CGPoint(x: x, y: y)
        tree.setScale(size)
        parent.addChild(tree)
        ellipse(tree, x: 3, y: -13, w: 34, h: 15, color: IslandColors.shadow)
        rect(tree, x: 0, y: -9, w: 5, h: 18, radius: 1.5, color: IslandColors.brown)
        if pine {
            polygon(tree, points: [CGPoint(x: -18, y: -6), CGPoint(x: 0, y: 29), CGPoint(x: 18, y: -6)], color: IslandColors.darkMoss)
            polygon(tree, points: [CGPoint(x: -13, y: 5), CGPoint(x: 0, y: 29), CGPoint(x: 11, y: 5)], color: IslandColors.leaf)
            polygon(tree, points: [CGPoint(x: -10, y: 12), CGPoint(x: 0, y: 31), CGPoint(x: 0, y: 12)], color: IslandColors.lightLeaf)
        } else {
            ellipse(tree, x: 3, y: 4, w: 35, h: 30, color: IslandColors.darkMoss)
            ellipse(tree, x: -6, y: 9, w: 28, h: 27, color: IslandColors.leaf)
            ellipse(tree, x: 6, y: 13, w: 28, h: 29, color: IslandColors.leaf)
            ellipse(tree, x: -4, y: 18, w: 23, h: 18, color: IslandColors.lightLeaf)
            if fruit {
                for p in [CGPoint(x: -10, y: 8), CGPoint(x: 10, y: 14), CGPoint(x: 3, y: -2)] {
                    ellipse(tree, x: p.x, y: p.y, w: 5, h: 5, color: IslandColors.terracotta)
                    ellipse(tree, x: p.x - 0.7, y: p.y + 0.7, w: 1.8, h: 1.8, color: UIColor(hex: 0xE6AE73))
                }
            }
        }
    }

    static func building(_ piece: VisualPiece, on parent: SKNode) {
        let node = SKNode()
        node.zPosition = 15
        parent.addChild(node)
        switch piece {
        case .quarry:
            ellipse(node, x: 4, y: -18, w: 72, h: 43, color: IslandColors.shadow)
            polygon(node, points: [.init(x: -35, y: -15), .init(x: -33, y: 18), .init(x: -12, y: 33), .init(x: 23, y: 25), .init(x: 33, y: 1), .init(x: 20, y: -23)], color: IslandColors.stone)
            polygon(node, points: [.init(x: -27, y: -10), .init(x: -27, y: 13), .init(x: -9, y: 25), .init(x: 17, y: 18), .init(x: 24, y: 0), .init(x: 13, y: -16)], color: IslandColors.stoneLight)
            polygon(node, points: [.init(x: -18, y: -4), .init(x: -17, y: 10), .init(x: -3, y: 17), .init(x: 13, y: 10), .init(x: 13, y: -7), .init(x: 2, y: -12)], color: UIColor(hex: 0x7D887C))
            polygon(node, points: [.init(x: -9, y: 0), .init(x: -8, y: 8), .init(x: 4, y: 10), .init(x: 9, y: -4), .init(x: 0, y: -7)], color: UIColor(hex: 0x607369))
            rect(node, x: 26, y: -1, w: 6, h: 47, radius: 1, color: IslandColors.brown)
            rect(node, x: 13, y: 23, w: 33, h: 5, radius: 1, color: IslandColors.terracotta)
            line(node, points: [.init(x: 4, y: 23), .init(x: 4, y: 6)], color: IslandColors.ink, width: 1.5)
            rect(node, x: 4, y: 3, w: 8, h: 6, radius: 1, color: IslandColors.brown)
            rect(node, x: -23, y: -23, w: 15, h: 11, radius: 2, color: IslandColors.stoneLight)
            rect(node, x: -4, y: -27, w: 12, h: 9, radius: 2, color: IslandColors.stoneLight)
        case .orchard:
            line(node, points: [.init(x: -35, y: -30), .init(x: 30, y: -30)], color: UIColor(hex: 0x9D885D), width: 2)
            for x in stride(from: -30, through: 30, by: 15) {
                rect(node, x: CGFloat(x), y: -30, w: 2.5, h: 11, radius: 1, color: IslandColors.brown)
            }
            tree(node, x: -21, y: 8, size: 1.05, fruit: true)
            tree(node, x: 20, y: 9, size: 1.1, fruit: true)
            tree(node, x: 0, y: -20, size: 1.1, fruit: true)
        case .lumberCamp:
            ellipse(node, x: 2, y: -15, w: 69, h: 37, color: IslandColors.shadow)
            rect(node, x: 7, y: 0, w: 39, h: 33, radius: 2, color: UIColor(hex: 0xDDCEA7))
            rect(node, x: 24, y: -1, w: 7, h: 30, color: UIColor(hex: 0xB5A47D))
            polygon(node, points: [.init(x: -18, y: 12), .init(x: 3, y: 30), .init(x: 32, y: 18), .init(x: 12, y: 1)], color: IslandColors.terracotta)
            polygon(node, points: [.init(x: -18, y: 12), .init(x: 3, y: 30), .init(x: 3, y: 12)], color: IslandColors.roofHighlight)
            rect(node, x: 10, y: -8, w: 10, h: 16, radius: 1, color: IslandColors.brown)
            for offset in [-9.0, 0.0, 9.0] {
                rect(node, x: -21, y: CGFloat(offset - 12), w: 29, h: 7, radius: 3, color: IslandColors.brown)
                ellipse(node, x: -34, y: CGFloat(offset - 12), w: 7, h: 7, color: UIColor(hex: 0xD2B684))
                ellipse(node, x: -34, y: CGFloat(offset - 12), w: 3, h: 3, color: UIColor(hex: 0xAB8B5E))
            }
            line(node, points: [.init(x: 25, y: -27), .init(x: 36, y: -11)], color: IslandColors.brown, width: 3)
            polygon(node, points: [.init(x: 31, y: -13), .init(x: 37, y: -8), .init(x: 43, y: -13), .init(x: 38, y: -18)], color: IslandColors.stoneLight)
        case .field:
            rect(node, x: 2, y: -4, w: 76, h: 68, radius: 6, color: IslandColors.shadow)
            rect(node, x: 0, y: 0, w: 72, h: 64, radius: 5, color: UIColor(hex: 0xB19363))
            for row in 0..<4 {
                let y = CGFloat(row * 15 - 23)
                line(node, points: [.init(x: -29, y: y), .init(x: 29, y: y)], color: UIColor(hex: 0x8F7953), width: 4)
                for col in 0..<5 {
                    let x = CGFloat(col * 13 - 26)
                    line(node, points: [.init(x: x, y: y - 1), .init(x: x, y: y + 7)], color: IslandColors.darkMoss, width: 2)
                    ellipse(node, x: x - 2, y: y + 4, w: 6, h: 3.5, color: IslandColors.lightLeaf)
                    ellipse(node, x: x + 2, y: y + 6, w: 6, h: 3.5, color: IslandColors.leaf)
                }
            }
        case .reservoir:
            ellipse(node, x: 3, y: -7, w: 75, h: 66, color: IslandColors.shadow)
            ellipse(node, x: 0, y: 0, w: 72, h: 65, color: IslandColors.stone)
            ellipse(node, x: -1, y: 4, w: 66, h: 60, color: IslandColors.stoneLight)
            ellipse(node, x: -1, y: 4, w: 54, h: 48, color: IslandColors.deepWater)
            ellipse(node, x: -2, y: 7, w: 49, h: 40, color: IslandColors.water)
            line(node, points: [.init(x: -15, y: 15), .init(x: -4, y: 16), .init(x: 3, y: 14)], color: UIColor(hex: 0xC4DDD6), width: 2)
            line(node, points: [.init(x: 2, y: 4), .init(x: 16, y: 4)], color: UIColor(hex: 0xB4D4D0), width: 2)
            rect(node, x: 0, y: -29, w: 15, h: 23, radius: 2, color: IslandColors.brown)
            rect(node, x: 0, y: -26, w: 9, h: 20, radius: 1, color: IslandColors.water)
            rect(node, x: 0, y: -22, w: 19, h: 4, radius: 1, color: IslandColors.terracotta)
        case .depot:
            ellipse(node, x: 3, y: -20, w: 77, h: 38, color: IslandColors.shadow)
            rect(node, x: 0, y: -20, w: 66, h: 14, radius: 3, color: IslandColors.brown)
            rect(node, x: 0, y: -4, w: 60, h: 39, radius: 2, color: UIColor(hex: 0xE8DBB7))
            rect(node, x: 26, y: -4, w: 8, h: 39, color: UIColor(hex: 0xC5B58C))
            polygon(node, points: [.init(x: -36, y: 14), .init(x: -2, y: 35), .init(x: 36, y: 14), .init(x: 1, y: -1)], color: IslandColors.terracotta)
            polygon(node, points: [.init(x: -36, y: 14), .init(x: -2, y: 35), .init(x: 1, y: -1)], color: IslandColors.roofHighlight)
            line(node, points: [.init(x: -1, y: 31), .init(x: 31, y: 14)], color: UIColor(hex: 0xA35A42), width: 2)
            rect(node, x: 0, y: -12, w: 17, h: 23, radius: 2, color: IslandColors.darkMoss)
            rect(node, x: -21, y: -4, w: 8, h: 9, radius: 1.5, color: IslandColors.water)
            rect(node, x: 19, y: -4, w: 8, h: 9, radius: 1.5, color: IslandColors.water)
            rect(node, x: 25, y: 29, w: 3, h: 32, radius: 1, color: IslandColors.brown)
            polygon(node, points: [.init(x: 26, y: 44), .init(x: 43, y: 40), .init(x: 26, y: 34)], color: IslandColors.paper)
            rect(node, x: -27, y: -25, w: 12, h: 10, radius: 1, color: IslandColors.road)
        case .road:
            rect(node, x: 0, y: -2, w: 29, h: 85, radius: 4, color: IslandColors.darkRoad)
            rect(node, x: -1, y: 0, w: 24, h: 85, radius: 3, color: IslandColors.road)
            for y in stride(from: -34, through: 34, by: 17) {
                line(node, points: [.init(x: -8, y: CGFloat(y)), .init(x: 6, y: CGFloat(y + 2))], color: IslandColors.darkRoad.withAlphaComponent(0.4), width: 1.5)
            }
        case .bridge:
            rect(node, x: 0, y: -3, w: 46, h: 82, radius: 2, color: IslandColors.shadow)
            for y in stride(from: -36, through: 36, by: 9) {
                rect(node, x: 0, y: CGFloat(y), w: 44, h: 7, radius: 1.5, color: UIColor(hex: 0xD9BE8B))
            }
            rect(node, x: -20, y: 2, w: 4, h: 85, radius: 1.5, color: IslandColors.brown)
            rect(node, x: 20, y: 2, w: 4, h: 85, radius: 1.5, color: IslandColors.brown)
        }
    }
}
