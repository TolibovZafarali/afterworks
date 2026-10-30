import SwiftUI
import AfterworksCore

enum Palette {
    static let paper = Color(red: 0.96, green: 0.94, blue: 0.89)
    static let ink = Color(red: 0.16, green: 0.25, blue: 0.21)
    static let moss = Color(red: 0.34, green: 0.44, blue: 0.31)
    static let faint = Color(red: 0.88, green: 0.87, blue: 0.80)
    static let clay = Color(red: 0.68, green: 0.33, blue: 0.23)
    static let water = Color(red: 0.36, green: 0.57, blue: 0.62)
    static let secondary = Color(red: 0.39, green: 0.43, blue: 0.36)
    static let gold = Color(red: 0.74, green: 0.52, blue: 0.18)
    static let goldLight = Color(red: 0.95, green: 0.78, blue: 0.38)
}

struct CoinGlyph: View {
    var size: CGFloat = 18
    var body: some View {
        ZStack {
            Circle().fill(Palette.gold).offset(y: size * 0.08)
            Circle().fill(Palette.goldLight)
            Circle().strokeBorder(Palette.gold.opacity(0.8), lineWidth: max(1, size * 0.07)).padding(size * 0.16)
            RoundedRectangle(cornerRadius: 1).fill(Palette.gold).frame(width: size * 0.13, height: size * 0.43)
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct StarRating: View {
    let stars: Int
    var size: CGFloat = 15
    var body: some View {
        HStack(spacing: size * 0.22) {
            ForEach(0..<3) { index in
                Image(systemName: index < stars ? "star.fill" : "star")
                    .font(.system(size: size, weight: .medium))
                    .foregroundStyle(index < stars ? Palette.gold : Palette.secondary.opacity(0.35))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stars) of 3 stars")
    }
}

extension Piece {
    var visual: VisualPiece { VisualPiece(rawValue: rawValue)! }
    var shortTitle: String { self == .lumberCamp ? "Lumber" : title }
}

extension Terrain {
    var visual: VisualTerrain { VisualTerrain(rawValue: rawValue)! }
}

extension Position {
    var visual: GridPoint { GridPoint(row: row, col: col) }
}

struct PaperButtonStyle: ButtonStyle {
    var filled = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(filled ? Palette.paper : Palette.ink)
            .background(filled ? Palette.ink : Palette.faint.opacity(0.55), in: RoundedRectangle(cornerRadius: 15))
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct ResourceMark: View {
    let resource: Resource
    var size: CGFloat = 15

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }

    private var symbol: String {
        switch resource {
        case .stone: return "diamond.fill"
        case .food: return "leaf.fill"
        case .timber: return "tree.fill"
        }
    }

    private var color: Color {
        switch resource {
        case .stone: return Palette.secondary
        case .food: return Palette.clay
        case .timber: return Palette.moss
        }
    }
}

struct SheetHeading: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow.uppercased()).font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(Palette.secondary)
            Text(title).font(.custom("Georgia", size: 30)).foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
