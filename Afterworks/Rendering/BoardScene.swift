import SpriteKit
import UIKit

@MainActor
final class BoardScene: SKScene {
    var onTap: ((GridPoint) -> Void)?
    var onRoadStroke: (([GridPoint]) -> Void)?
    var onHover: ((GridPoint?) -> Void)?
    var drawsRoads = false
    var inputEnabled = true

    private let shoreLayer = SKNode()
    private let terrainLayer = SKNode()
    private let routeLayer = SKNode()
    private let buildingLayer = SKNode()
    private let highlightLayer = SKNode()
    private let deliveryLayer = SKNode()
    private let hoverLayer = SKNode()
    private let transitionLayer = SKNode()
    private var currentModel: BoardSceneModel?
    private var cachedTerrain: [String] = []
    private var cachedBuildings: [String] = []
    private var stroke: [GridPoint] = []
    private var startPoint: GridPoint?

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
        isUserInteractionEnabled = true
        for (index, layer) in [shoreLayer, terrainLayer, routeLayer, buildingLayer,
                               highlightLayer, deliveryLayer, hoverLayer, transitionLayer].enumerated() {
            layer.zPosition = CGFloat(index * 10)
            addChild(layer)
        }
    }

    required init?(coder aDecoder: NSCoder) { nil }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 20, size.height > 20 else { return }
        cachedTerrain = []
        cachedBuildings = []
        if let currentModel { render(currentModel, force: true) }
    }

    func render(_ model: BoardSceneModel) {
        render(model, force: false)
    }

    private func render(_ model: BoardSceneModel, force: Bool) {
        guard force || currentModel != model else { return }
        let previousMotion = currentModel?.reduceMotion
        currentModel = model
        let terrainKey = model.cells.map { "\($0.point.id):\($0.terrain.rawValue)" }
        if terrainKey != cachedTerrain || force || previousMotion != model.reduceMotion {
            cachedTerrain = terrainKey
            buildTerrain(model)
        }
        let buildingsKey = model.cells.map {
            "\($0.point.id):\($0.building?.rawValue ?? "-"):\($0.infrastructure?.rawValue ?? "-"):\($0.isInherited):\(String(describing: $0.isConnected))"
        }
        if buildingsKey != cachedBuildings || force {
            cachedBuildings = buildingsKey
            buildStructures(model)
        }
        buildHighlights(model)
    }

    private var gridSide: CGFloat { max(1, min(size.width, size.height) - 40) }
    private var cellSize: CGFloat { gridSide / 7 }
    private var gridLeft: CGFloat { (size.width - gridSide) / 2 + 4 }
    private var gridBottom: CGFloat { (size.height - gridSide) / 2 - 4 }

    private func center(of point: GridPoint) -> CGPoint {
        CGPoint(x: gridLeft + (CGFloat(point.col) + 0.5) * cellSize,
                y: gridBottom + (CGFloat(6 - point.row) + 0.5) * cellSize)
    }

    func gridPoint(atViewPoint point: CGPoint, in viewSize: CGSize) -> GridPoint? {
        let side = min(viewSize.width, viewSize.height) - 40
        guard side > 0 else { return nil }
        let left = (viewSize.width - side) / 2 + 4
        let bottom = (viewSize.height - side) / 2 - 4
        let px = point.x - left
        let py = viewSize.height - point.y - bottom
        guard px >= 0, py >= 0, px < side, py < side else { return nil }
        return GridPoint(row: 6 - Int(py / (side / 7)), col: Int(px / (side / 7)))
    }

    func viewCenter(of point: GridPoint, in viewSize: CGSize) -> CGPoint {
        let side = min(viewSize.width, viewSize.height) - 40
        let cell = side / 7
        let left = (viewSize.width - side) / 2 + 4
        let bottom = (viewSize.height - side) / 2 - 4
        return CGPoint(x: left + (CGFloat(point.col) + 0.5) * cell,
                       y: viewSize.height - bottom - (CGFloat(6 - point.row) + 0.5) * cell)
    }

    private func point(atScenePoint point: CGPoint) -> GridPoint? {
        let px = point.x - gridLeft
        let py = point.y - gridBottom
        guard px >= 0, py >= 0, px < gridSide, py < gridSide else { return nil }
        return GridPoint(row: 6 - Int(py / cellSize), col: Int(px / cellSize))
    }

    private func buildTerrain(_ model: BoardSceneModel) {
        shoreLayer.removeAllChildren()
        terrainLayer.removeAllChildren()
        let boardCenter = CGPoint(x: gridLeft + gridSide / 2, y: gridBottom + gridSide / 2)
        let sea = SKShapeNode(rectOf: CGSize(width: gridSide + 28, height: gridSide + 28), cornerRadius: 24)
        sea.position = CGPoint(x: boardCenter.x, y: boardCenter.y - 1)
        sea.fillColor = UIColor(hex: 0xD4DECE)
        sea.strokeColor = .clear
        shoreLayer.addChild(sea)
        let shadow = SKShapeNode(rectOf: CGSize(width: gridSide + 13, height: gridSide + 13), cornerRadius: 15)
        shadow.position = CGPoint(x: boardCenter.x + 1, y: boardCenter.y - 5)
        shadow.fillColor = UIColor(hex: 0x556B54).withAlphaComponent(0.2)
        shadow.strokeColor = .clear
        shoreLayer.addChild(shadow)
        let shore = SKShapeNode(rectOf: CGSize(width: gridSide + 12, height: gridSide + 12), cornerRadius: 14)
        shore.position = boardCenter
        shore.fillColor = IslandColors.sand
        shore.strokeColor = UIColor(hex: 0xE9DCB6)
        shore.lineWidth = 2
        shoreLayer.addChild(shore)
        let underlay = SKShapeNode(rectOf: CGSize(width: gridSide, height: gridSide), cornerRadius: 5)
        underlay.position = boardCenter
        underlay.fillColor = IslandColors.moss
        underlay.strokeColor = .clear
        shoreLayer.addChild(underlay)

        for index in 0..<7 {
            let column = SKLabelNode(fontNamed: "AvenirNext-Medium")
            column.text = String(UnicodeScalar(65 + index)!)
            column.fontSize = max(8, cellSize * 0.2)
            column.fontColor = IslandColors.ink.withAlphaComponent(0.55)
            column.position = CGPoint(x: gridLeft + (CGFloat(index) + 0.5) * cellSize,
                                      y: gridBottom + gridSide + 11)
            shoreLayer.addChild(column)
            let row = SKLabelNode(fontNamed: "AvenirNext-Medium")
            row.text = "\(index + 1)"
            row.fontSize = max(8, cellSize * 0.2)
            row.fontColor = IslandColors.ink.withAlphaComponent(0.55)
            row.verticalAlignmentMode = .center
            row.position = CGPoint(x: gridLeft - 13,
                                   y: gridBottom + (CGFloat(6 - index) + 0.5) * cellSize)
            shoreLayer.addChild(row)
        }

        for cell in model.cells {
            let node = SKNode()
            node.position = center(of: cell.point)
            node.setScale(cellSize / 100)
            terrainLayer.addChild(node)
            let odd = (cell.point.row + cell.point.col) % 2 == 0
            let ground: UIColor
            switch cell.terrain {
            case .grass, .woodland: ground = odd ? IslandColors.grass : IslandColors.grassAlternate
            case .stone: ground = odd ? UIColor(hex: 0xC6C6A6) : UIColor(hex: 0xBEBF9F)
            case .water: ground = IslandColors.water
            case .wetland: ground = IslandColors.wetland
            case .cliff: ground = odd ? UIColor(hex: 0xADB39F) : UIColor(hex: 0xA7AF99)
            }
            let tile = IslandArt.rect(node, x: 0, y: 0, w: 99.4, h: 99.4,
                                      radius: 3, color: ground)
            tile.strokeColor = IslandColors.ink.withAlphaComponent(0.045)
            tile.lineWidth = 0.8
            switch cell.terrain {
            case .cliff:
                let shift = CGFloat((cell.point.row + cell.point.col) % 3 - 1) * 7
                let crag = SKNode()
                crag.setScale(0.75)
                node.addChild(crag)
                IslandArt.polygon(crag, points: [
                    .init(x: -37, y: -24), .init(x: -31, y: 7), .init(x: -7 + shift, y: 32),
                    .init(x: 18, y: 24), .init(x: 39, y: -10), .init(x: 27, y: -28)
                ], color: UIColor(hex: 0x8F9B85))
                IslandArt.polygon(crag, points: [
                    .init(x: -31, y: 7), .init(x: -7 + shift, y: 32), .init(x: 18, y: 24),
                    .init(x: 4, y: 3), .init(x: -14, y: -1)
                ], color: UIColor(hex: 0xBAC2AA))
                IslandArt.line(crag, points: [.init(x: 4, y: 3), .init(x: 12, y: -15), .init(x: 27, y: -28)],
                               color: UIColor(hex: 0x77866F).withAlphaComponent(0.5), width: 2)
            case .grass:
                grassDetails(node, point: cell.point)
            case .stone:
                grassDetails(node, point: cell.point)
                for (index, p) in [CGPoint(x: -22, y: 19), CGPoint(x: 19, y: 8), CGPoint(x: -9, y: -17)].enumerated() {
                    let scale = CGFloat(index == 1 ? 1 : 0.7)
                    IslandArt.ellipse(node, x: p.x + 2, y: p.y - 5, w: 30 * scale, h: 14 * scale, color: IslandColors.shadow)
                    IslandArt.polygon(node, points: [CGPoint(x: p.x - 14 * scale, y: p.y - 5 * scale),
                        CGPoint(x: p.x - 10 * scale, y: p.y + 9 * scale),
                        CGPoint(x: p.x + 3 * scale, y: p.y + 14 * scale),
                        CGPoint(x: p.x + 16 * scale, y: p.y + 2 * scale),
                        CGPoint(x: p.x + 9 * scale, y: p.y - 9 * scale)], color: IslandColors.stone)
                    IslandArt.polygon(node, points: [CGPoint(x: p.x - 10 * scale, y: p.y + 9 * scale),
                        CGPoint(x: p.x + 3 * scale, y: p.y + 14 * scale),
                        CGPoint(x: p.x + 9 * scale, y: p.y + 3 * scale),
                        CGPoint(x: p.x - 5 * scale, y: p.y - 1 * scale)], color: IslandColors.stoneLight)
                }
            case .water:
                let inner = IslandArt.rect(node, x: 1, y: -1, w: 81, h: 78, radius: 18,
                                           color: IslandColors.deepWater.withAlphaComponent(0.22))
                inner.zPosition = 1
                for (index, y) in [-24.0, 2.0, 27.0].enumerated() {
                    let wave = IslandArt.line(node, points: [.init(x: -30 + Double(index * 8), y: y),
                        .init(x: -14 + Double(index * 8), y: y + 1.5), .init(x: -5 + Double(index * 8), y: y)],
                        color: UIColor(hex: 0xD2E4D9).withAlphaComponent(0.6), width: 2, z: 2)
                    if !model.reduceMotion {
                        wave.run(.repeatForever(.sequence([
                            .group([.moveBy(x: 5, y: 0, duration: 2.2 + Double(index) * 0.3), .fadeAlpha(to: 0.4, duration: 2.2)]),
                            .group([.moveBy(x: -5, y: 0, duration: 2.2 + Double(index) * 0.3), .fadeAlpha(to: 1, duration: 2.2)])
                        ])))
                    }
                }
                for (dx, dy) in [(-39.0, -31.0), (34.0, 27.0)] {
                    IslandArt.ellipse(node, x: dx, y: dy, w: 9, h: 5, color: UIColor(hex: 0xADC191))
                }
            case .woodland:
                grassDetails(node, point: cell.point)
                IslandArt.tree(node, x: -22, y: 12, size: 1.1, pine: true)
                IslandArt.tree(node, x: 18, y: 15, size: 1.05)
                IslandArt.tree(node, x: 0, y: -18, size: 1.25, pine: true)
            case .wetland:
                IslandArt.ellipse(node, x: -15, y: 5, w: 39, h: 18, color: IslandColors.water.withAlphaComponent(0.65))
                IslandArt.ellipse(node, x: 20, y: -24, w: 35, h: 14, color: IslandColors.water.withAlphaComponent(0.6))
                for p in [CGPoint(x: -23, y: -18), .init(x: 21, y: 18), .init(x: 7, y: -5)] {
                    for dx in [-4.0, 2.0, 7.0] {
                        IslandArt.line(node, points: [CGPoint(x: p.x + dx, y: p.y - 7),
                            CGPoint(x: p.x + dx - 1, y: p.y + 7)], color: IslandColors.moss, width: 2)
                        IslandArt.ellipse(node, x: p.x + dx - 1, y: p.y + 7, w: 3, h: 7, color: IslandColors.brown)
                    }
                }
            }
        }
    }

    private func grassDetails(_ node: SKNode, point: GridPoint) {
        let seed = point.row * 13 + point.col * 7
        for index in 0..<4 {
            let x = CGFloat((seed + index * 23) % 73 - 36)
            let y = CGFloat((seed * 3 + index * 19) % 69 - 34)
            IslandArt.ellipse(node, x: x, y: y, w: CGFloat(3 + index % 2), h: 2,
                              color: IslandColors.moss.withAlphaComponent(0.24))
        }
        if seed % 3 == 0 {
            IslandArt.line(node, points: [.init(x: 29, y: -30), .init(x: 27, y: -25)],
                           color: IslandColors.moss.withAlphaComponent(0.3), width: 1.5)
            IslandArt.line(node, points: [.init(x: 29, y: -30), .init(x: 32, y: -26)],
                           color: IslandColors.moss.withAlphaComponent(0.3), width: 1.5)
        }
    }

    private func buildStructures(_ model: BoardSceneModel) {
        routeLayer.removeAllChildren()
        buildingLayer.removeAllChildren()
        let byPoint = Dictionary(uniqueKeysWithValues: model.cells.map { ($0.point, $0) })
        for cell in model.cells {
            if let infrastructure = cell.infrastructure {
                let node = SKNode()
                node.position = center(of: cell.point)
                node.setScale(cellSize / 100)
                routeLayer.addChild(node)
                let neighbors = [GridPoint(row: cell.point.row - 1, col: cell.point.col),
                                 GridPoint(row: cell.point.row + 1, col: cell.point.col),
                                 GridPoint(row: cell.point.row, col: cell.point.col - 1),
                                 GridPoint(row: cell.point.row, col: cell.point.col + 1)]
                let linked = neighbors.filter { neighbor in
                    guard let other = byPoint[neighbor] else { return false }
                    return other.infrastructure != nil || other.building != nil
                }
                if infrastructure == .bridge {
                    drawBridge(node, cell: cell, linked: linked)
                } else {
                    let color = cell.isInherited ? IslandColors.oldRoad : IslandColors.road
                    IslandArt.ellipse(node, x: 0, y: -2, w: 32, h: 32, color: IslandColors.darkRoad)
                    for neighbor in linked {
                        let end = CGPoint(x: CGFloat(neighbor.col - cell.point.col) * 50,
                                          y: CGFloat(cell.point.row - neighbor.row) * 50)
                        IslandArt.line(node, points: [.zero, end], color: IslandColors.darkRoad, width: 31)
                        IslandArt.line(node, points: [.zero, end], color: color, width: 24, z: 1)
                    }
                    IslandArt.ellipse(node, x: 0, y: 0, w: 24, h: 24, color: color, z: 2)
                    if linked.isEmpty {
                        IslandArt.rect(node, x: 0, y: 0, w: 25, h: 42, radius: 7, color: color, z: 2)
                    }
                    IslandArt.ellipse(node, x: -5, y: 6, w: 5, h: 2, color: IslandColors.darkRoad.withAlphaComponent(0.4), z: 3)
                    IslandArt.ellipse(node, x: 5, y: -7, w: 4, h: 2, color: IslandColors.darkRoad.withAlphaComponent(0.4), z: 3)
                }
            }
            if let building = cell.building {
                let node = SKNode()
                node.position = center(of: cell.point)
                node.setScale(cellSize / 100)
                node.zPosition = CGFloat(cell.point.row)
                buildingLayer.addChild(node)
                IslandArt.building(building, on: node)
                if let connected = cell.isConnected, building != .depot {
                    connectionBadge(node, connected: connected)
                }
            }
        }
    }

    private func drawBridge(_ node: SKNode, cell: BoardCellVisual, linked: [GridPoint]) {
        let horizontal = linked.contains { $0.col != cell.point.col }
        let vertical = linked.contains { $0.row != cell.point.row }
        func span(horizontal: Bool) {
            let span = SKNode()
            span.zRotation = horizontal ? .pi / 2 : 0
            node.addChild(span)
            IslandArt.rect(span, x: 3, y: -3, w: 40, h: 104, radius: 1, color: IslandColors.shadow)
            for y in stride(from: -45, through: 45, by: 10) {
                IslandArt.rect(span, x: 0, y: CGFloat(y), w: 39, h: 8.5, radius: 1,
                               color: cell.isInherited ? UIColor(hex: 0xC9B68E) : UIColor(hex: 0xDBC395))
            }
            IslandArt.rect(span, x: -19, y: 1, w: 4, h: 102, radius: 1, color: IslandColors.brown)
            IslandArt.rect(span, x: 19, y: 1, w: 4, h: 102, radius: 1, color: IslandColors.brown)
        }
        if horizontal { span(horizontal: true) }
        if vertical || !horizontal { span(horizontal: false) }
    }

    private func connectionBadge(_ node: SKNode, connected: Bool) {
        let badge = SKNode()
        badge.position = CGPoint(x: 33, y: 33)
        badge.zPosition = 50
        node.addChild(badge)
        IslandArt.ellipse(badge, x: 0, y: 0, w: 17, h: 17, color: IslandColors.paper)
        IslandArt.ellipse(badge, x: 0, y: 0, w: 13, h: 13,
                          color: connected ? IslandColors.darkMoss : IslandColors.terracotta)
        if connected {
            IslandArt.line(badge, points: [.init(x: -3, y: 0), .init(x: -0.5, y: -2.5), .init(x: 3.5, y: 2.5)],
                           color: IslandColors.paper, width: 1.9)
        } else {
            IslandArt.line(badge, points: [.init(x: 0, y: 3), .init(x: 0, y: -0.6)],
                           color: IslandColors.paper, width: 1.6)
            IslandArt.ellipse(badge, x: 0, y: -3, w: 1.8, h: 1.8, color: IslandColors.paper)
        }
    }

    private func buildHighlights(_ model: BoardSceneModel) {
        highlightLayer.removeAllChildren()
        for cell in model.cells {
            let position = center(of: cell.point)
            if cell.placementAllowed == true {
                let valid = SKShapeNode(rectOf: CGSize(width: cellSize - 5, height: cellSize - 5), cornerRadius: 5)
                valid.position = position
                valid.fillColor = IslandColors.paper.withAlphaComponent(0.09)
                valid.strokeColor = IslandColors.paper.withAlphaComponent(0.8)
                valid.lineWidth = 1.2
                highlightLayer.addChild(valid)
                let dot = SKShapeNode(circleOfRadius: 2)
                dot.position = CGPoint(x: position.x, y: position.y - cellSize * 0.33)
                dot.fillColor = IslandColors.paper
                dot.strokeColor = .clear
                highlightLayer.addChild(dot)
            }
            if cell.futureChanged {
                let future = SKShapeNode(rectOf: CGSize(width: cellSize - 4, height: cellSize - 4), cornerRadius: 5)
                future.position = position
                future.fillColor = .clear
                future.strokeColor = UIColor(hex: 0xF6E7BA)
                future.lineWidth = 2
                highlightLayer.addChild(future)
                let star = SKLabelNode(fontNamed: "AvenirNext-Bold")
                star.text = "+"
                star.fontSize = 10
                star.fontColor = IslandColors.paper
                star.position = CGPoint(x: position.x - cellSize * 0.31, y: position.y + cellSize * 0.2)
                highlightLayer.addChild(star)
            }
            if cell.isSelected {
                let selected = SKShapeNode(rectOf: CGSize(width: cellSize - 2, height: cellSize - 2), cornerRadius: 6)
                selected.position = position
                selected.fillColor = IslandColors.paper.withAlphaComponent(0.1)
                selected.strokeColor = IslandColors.ink
                selected.lineWidth = 2
                highlightLayer.addChild(selected)
            }
        }
    }

    func showHover(at point: GridPoint?, allowed: Bool = true, piece: VisualPiece? = nil) {
        hoverLayer.removeAllChildren()
        guard let point else { return }
        let position = center(of: point)
        let ring = SKShapeNode(rectOf: CGSize(width: cellSize - 1, height: cellSize - 1), cornerRadius: 6)
        ring.position = position
        ring.fillColor = IslandColors.paper.withAlphaComponent(0.25)
        ring.strokeColor = allowed ? IslandColors.ink : IslandColors.terracotta
        ring.lineWidth = 2.5
        hoverLayer.addChild(ring)
        if let piece {
            let floating = SKNode()
            floating.position = CGPoint(x: position.x, y: min(size.height - cellSize * 0.4, position.y + cellSize * 1.05))
            floating.setScale(cellSize * 0.8 / 100)
            let disc = SKShapeNode(circleOfRadius: 47)
            disc.fillColor = IslandColors.paper.withAlphaComponent(0.94)
            disc.strokeColor = allowed ? IslandColors.ink.withAlphaComponent(0.3) : IslandColors.terracotta
            disc.lineWidth = 2
            floating.addChild(disc)
            IslandArt.building(piece, on: floating)
            hoverLayer.addChild(floating)
        }
    }

    func animatePlacement(at point: GridPoint) {
        guard currentModel?.reduceMotion != true else { return }
        let ring = SKShapeNode(circleOfRadius: cellSize * 0.24)
        ring.position = center(of: point)
        ring.strokeColor = IslandColors.paper
        ring.fillColor = .clear
        ring.lineWidth = 2
        deliveryLayer.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 1.7, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
    }

    @discardableResult
    func animateDeliveries(_ deliveries: [DeliveryVisual]) -> TimeInterval {
        stopActions(in: deliveryLayer)
        deliveryLayer.removeAllChildren()
        var duration: TimeInterval = 0
        for (index, delivery) in deliveries.enumerated() {
            guard let first = delivery.route.first, let last = delivery.route.last else { continue }
            if currentModel?.reduceMotion == true {
                arrival(at: last)
                duration = max(duration, 0.2)
                continue
            }
            let travelDuration = Double(index) * 0.18 + Double(delivery.route.count - 1) * 0.17
            duration = max(duration, travelDuration + 0.45)
            let cart = SKNode()
            cart.position = center(of: first)
            cart.setScale(cellSize / 100)
            cart.zPosition = 1
            IslandArt.ellipse(cart, x: 2, y: -5, w: 22, h: 12, color: IslandColors.shadow)
            IslandArt.rect(cart, x: -7, y: -5, w: 4, h: 10, radius: 2, color: IslandColors.ink)
            IslandArt.rect(cart, x: 7, y: -5, w: 4, h: 10, radius: 2, color: IslandColors.ink)
            IslandArt.rect(cart, x: 0, y: 0, w: 20, h: 15, radius: 3, color: IslandColors.brown)
            let cargo: UIColor
            switch delivery.resource {
            case .stone: cargo = IslandColors.stoneLight
            case .food: cargo = UIColor(hex: 0xD7A663)
            case .timber: cargo = UIColor(hex: 0xBD8D5E)
            }
            for x in [-5.0, 1.0, 6.0] {
                IslandArt.rect(cart, x: x, y: 3, w: 5, h: 13, radius: 2, color: cargo)
            }
            deliveryLayer.addChild(cart)
            var actions: [SKAction] = [.wait(forDuration: Double(index) * 0.18)]
            for point in delivery.route.dropFirst() {
                let move = SKAction.move(to: center(of: point), duration: 0.17)
                move.timingMode = .linear
                actions.append(move)
            }
            actions.append(.run { [weak self] in self?.arrival(at: last) })
            actions.append(.fadeOut(withDuration: 0.1))
            actions.append(.removeFromParent())
            cart.run(.sequence(actions))
        }
        return duration
    }

    func cancelTransientAnimations() {
        for layer in [deliveryLayer, hoverLayer, transitionLayer] {
            stopActions(in: layer)
            layer.removeAllChildren()
            layer.alpha = 1
        }
        for layer in [shoreLayer, terrainLayer, routeLayer, buildingLayer, highlightLayer] {
            layer.alpha = 1
        }
        stroke = []
        startPoint = nil
        onHover?(nil)
    }

    private func stopActions(in node: SKNode) {
        node.removeAllActions()
        for child in node.children { stopActions(in: child) }
    }

    private func arrival(at point: GridPoint) {
        let ring = SKShapeNode(circleOfRadius: cellSize * 0.2)
        ring.position = center(of: point)
        ring.strokeColor = IslandColors.paper
        ring.fillColor = IslandColors.paper.withAlphaComponent(0.3)
        ring.lineWidth = 2
        deliveryLayer.addChild(ring)
        let duration = currentModel?.reduceMotion == true ? 0.2 : 0.45
        ring.run(.sequence([.group([.scale(to: 1.8, duration: duration), .fadeOut(withDuration: duration)]), .removeFromParent()]))
    }

    func animateEraTransition(completion: @escaping () -> Void) {
        stopActions(in: transitionLayer)
        transitionLayer.removeAllChildren()
        guard currentModel?.reduceMotion != true else {
            completion()
            return
        }
        let wash = SKShapeNode(rectOf: size, cornerRadius: 20)
        wash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        wash.fillColor = IslandColors.paper
        wash.strokeColor = .clear
        wash.alpha = 0
        transitionLayer.addChild(wash)
        for index in 0..<22 {
            let leaf = SKShapeNode(ellipseOf: CGSize(width: 4, height: 7))
            leaf.fillColor = [IslandColors.terracotta, IslandColors.moss, IslandColors.sand][index % 3]
            leaf.strokeColor = .clear
            leaf.position = CGPoint(x: CGFloat(index * 31 % max(1, Int(size.width))),
                                    y: CGFloat(index * 47 % max(1, Int(size.height))))
            leaf.alpha = 0
            transitionLayer.addChild(leaf)
            leaf.run(.sequence([.wait(forDuration: Double(index % 6) * 0.03),
                .group([.fadeIn(withDuration: 0.2), .moveBy(x: 22, y: -18, duration: 0.3), .rotate(byAngle: 0.8, duration: 0.3)]),
                .group([.fadeOut(withDuration: 0.4), .moveBy(x: 32, y: -20, duration: 0.4), .rotate(byAngle: 1.1, duration: 0.4)]),
                .removeFromParent()]))
        }
        wash.run(.sequence([.fadeAlpha(to: 0.9, duration: 0.35), .run(completion),
                            .fadeOut(withDuration: 0.55), .removeFromParent()]))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard inputEnabled, let touch = touches.first,
              let point = point(atScenePoint: touch.location(in: self)) else { return }
        startPoint = point
        stroke = [point]
        onHover?(point)
        if drawsRoads { showStroke() }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard inputEnabled, let touch = touches.first else { return }
        let point = point(atScenePoint: touch.location(in: self))
        onHover?(point)
        guard drawsRoads, let point, let previous = stroke.last, point != previous else { return }
        let distance = abs(previous.row - point.row) + abs(previous.col - point.col)
        if distance == 1 {
            if stroke.count >= 2 && stroke[stroke.count - 2] == point {
                stroke.removeLast()
            } else if !stroke.contains(point) {
                stroke.append(point)
            }
        } else if previous.row == point.row || previous.col == point.col {
            let rowStep = point.row == previous.row ? 0 : (point.row > previous.row ? 1 : -1)
            let colStep = point.col == previous.col ? 0 : (point.col > previous.col ? 1 : -1)
            for offset in 1...distance {
                let next = GridPoint(row: previous.row + rowStep * offset, col: previous.col + colStep * offset)
                if !stroke.contains(next) { stroke.append(next) }
            }
        }
        showStroke()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            stroke = []
            startPoint = nil
            hoverLayer.removeAllChildren()
            onHover?(nil)
        }
        guard inputEnabled, let touch = touches.first,
              let point = point(atScenePoint: touch.location(in: self)), startPoint != nil else { return }
        if drawsRoads, let onRoadStroke {
            onRoadStroke(stroke)
        } else if point == startPoint {
            onTap?(point)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        stroke = []
        startPoint = nil
        hoverLayer.removeAllChildren()
        onHover?(nil)
    }

    private func showStroke() {
        hoverLayer.removeAllChildren()
        for point in stroke {
            let highlight = SKShapeNode(rectOf: CGSize(width: cellSize - 4, height: cellSize - 4), cornerRadius: 5)
            highlight.position = center(of: point)
            highlight.fillColor = IslandColors.road.withAlphaComponent(0.65)
            highlight.strokeColor = IslandColors.ink.withAlphaComponent(0.7)
            highlight.lineWidth = 1.5
            hoverLayer.addChild(highlight)
        }
    }
}
