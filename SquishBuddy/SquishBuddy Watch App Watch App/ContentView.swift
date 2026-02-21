import SwiftUI
import Combine
import WatchKit
import AVFoundation

struct ContentView: View {
    private let tick = Timer.publish(every: GameTheme.tickInterval, on: .main, in: .common).autoconnect()

    private let levels: [BeatLevel] = [
        BeatLevel(
            name: "Rock Backbeat",
            pattern: [.down, .right, .left, .right, .down, .right, .left, .right],
            arrowsToSpawn: 16,
            spawnInterval: 0.48,
            speed: 84
        ),
        BeatLevel(
            name: "Boom Bap",
            pattern: [.down, .right, .left, .right, .down, .right, .left, .down],
            arrowsToSpawn: 18,
            spawnInterval: 0.44,
            speed: 96
        ),
        BeatLevel(
            name: "Disco Push",
            pattern: [.down, .right, .left, .right, .down, .up, .left, .right],
            arrowsToSpawn: 20,
            spawnInterval: 0.40,
            speed: 110
        ),
        BeatLevel(
            name: "Fast Hats",
            pattern: [.down, .right, .left, .right, .down, .right, .left, .up],
            arrowsToSpawn: 24,
            spawnInterval: 0.35,
            speed: 124
        )
    ]

    @State private var arrows: [FallingArrow] = []
    @State private var score = 0
    @State private var lives = GameTheme.maxLives
    @State private var currentLevelIndex = 0
    @State private var spawnAccumulator = 0.0
    @State private var phase: GamePhase = .start
    @State private var feedbackText = "Match arrows at the hit zone"
    @State private var spawnedInLevel = 0
    @State private var resolvedInLevel = 0
    @State private var combo = 0
    @State private var bestCombo = 0
    @State private var hitPulse = false
    @State private var judgePopup: JudgePopup?
    @State private var comboPopup: ComboPopup?
    @State private var activePads: Set<ArrowDirection> = []

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let hitY = height * GameTheme.hitZoneYFactor

            ZStack {
                background

                if phase == .freePlay {
                    freePlayPads(width: width, height: height)
                } else {
                    hitZone(width: width, hitY: hitY)

                    ForEach(arrows) { arrow in
                        ArrowChip(arrow: arrow)
                            .position(x: width / 2, y: arrow.y)
                    }

                    hud

                    if let popup = judgePopup {
                        Text(popup.text)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(popup.color)
                            .shadow(color: popup.color.opacity(0.6), radius: 6)
                            .position(x: width * 0.5, y: hitY - 22)
                            .transition(.opacity.combined(with: .scale))
                    }

                    if let popup = comboPopup {
                        Text(popup.text)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(GameTheme.comboColor)
                            .shadow(color: GameTheme.comboColor.opacity(0.7), radius: 6)
                            .position(x: width * 0.5, y: hitY - 40)
                            .transition(.opacity.combined(with: .scale))
                    }
                }

                overlayCard

                Color.clear
                    .contentShape(Rectangle())
                    .allowsHitTesting(phase == .playing)
                    .gesture(
                        DragGesture(minimumDistance: GameTheme.swipeMinDistance)
                            .onEnded { value in
                                guard let direction = swipeDirection(from: value.translation) else { return }
                                judgeSwipe(direction, hitY: hitY)
                            }
                    )
            }
            .onReceive(tick) { _ in
                updateGame(height: height, hitY: hitY)
            }
            .onAppear {
                DrumKitPlayer.shared.warmUp()
                withAnimation(.easeInOut(duration: GameTheme.pulseDuration).repeatForever(autoreverses: true)) {
                    hitPulse = true
                }
            }
        }
    }

    private var activeLevel: BeatLevel {
        levels[min(currentLevelIndex, levels.count - 1)]
    }

    private var background: some View {
        LinearGradient(
            colors: [GameTheme.bgTop, GameTheme.bgBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            RadialGradient(
                colors: [GameTheme.bgGlow.opacity(0.25), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 170
            )
        )
        .ignoresSafeArea()
    }

    private func hitZone(width: CGFloat, hitY: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(GameTheme.hitZoneFill)
                .frame(width: width * 0.82, height: GameTheme.hitZoneHeight)
                .overlay(
                    Capsule()
                        .stroke(GameTheme.hitZoneStroke, lineWidth: 1.8)
                )
                .scaleEffect(hitPulse ? 1.03 : 0.98)
                .opacity(hitPulse ? 1 : 0.88)
                .shadow(color: GameTheme.hitZoneGlow.opacity(0.35), radius: 8)

            HStack(spacing: 6) {
                ForEach(0..<18, id: \.self) { _ in
                    Capsule()
                        .fill(GameTheme.hitZoneDash)
                        .frame(width: 3, height: 2)
                }
            }
        }
        .position(x: width * 0.5, y: hitY)
    }

    private var hud: some View {
        VStack(spacing: 3) {
            HStack {
                Text("L\(currentLevelIndex + 1)")
                Spacer()
                Text("S\(score)")
            }
            .font(GameTheme.hudTitleFont)
            .foregroundStyle(.white)

            HStack {
                Text("♥ \(lives)")
                    .foregroundStyle(lives <= 2 ? GameTheme.miss : GameTheme.good)
                Spacer()
                Text("Combo \(combo)")
                    .foregroundStyle(combo > 0 ? GameTheme.comboColor : .white.opacity(0.7))
            }
            .font(GameTheme.hudSubFont)

            Text(feedbackText)
                .font(GameTheme.hudSubFont)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, GameTheme.hudHorizontalPadding)
        .padding(.top, GameTheme.hudTopPadding)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func freePlayPads(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                FreePlayQuadrant(
                    title: "Snare",
                    color: GameTheme.padSnare,
                    isActive: activePads.contains(.left),
                    action: { triggerFreePlayPad(.left) }
                )
                FreePlayQuadrant(
                    title: "Hi-hat",
                    color: GameTheme.padHihat,
                    isActive: activePads.contains(.right),
                    action: { triggerFreePlayPad(.right) }
                )
            }
            HStack(spacing: 0) {
                FreePlayQuadrant(
                    title: "Kick",
                    color: GameTheme.padKick,
                    isActive: activePads.contains(.down),
                    action: { triggerFreePlayPad(.down) }
                )
                FreePlayQuadrant(
                    title: "Crash",
                    color: GameTheme.padCrash,
                    isActive: activePads.contains(.up),
                    action: { triggerFreePlayPad(.up) }
                )
            }
        }
        .frame(width: width, height: height)
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    let startedNearBottom = value.startLocation.y > height * 0.78
                    let swipedUp = value.translation.height < -36
                    let mostlyVertical = abs(value.translation.height) > abs(value.translation.width)
                    if startedNearBottom && swipedUp && mostlyVertical {
                        resetAll()
                    }
                }
        )
    }

    @ViewBuilder
    private var overlayCard: some View {
        switch phase {
        case .start:
            StartMenuCard(
                title: "Arrow Pulse",
                primaryButton: "Start Level 1",
                secondaryButton: "Free Play",
                primaryAction: startLevel,
                secondaryAction: startFreePlay
            )
        case .betweenLevels:
            let nextLevel = currentLevelIndex + 1
            if nextLevel < levels.count {
                OverlayCard(
                    title: "Level \(nextLevel) Clear",
                    subtitle: "Next beat: \(levels[nextLevel].name)",
                    buttonTitle: "Start Level \(nextLevel + 1)",
                    footer: "Best combo \(bestCombo)",
                    action: startLevel
                )
            } else {
                OverlayCard(
                    title: "All Beats Cleared",
                    subtitle: "Final score \(score)",
                    buttonTitle: "Play Again",
                    footer: "Best combo \(bestCombo)",
                    action: resetAll
                )
            }
        case .gameOver:
            OverlayCard(
                title: "Game Over",
                subtitle: "You ran out of lives.",
                buttonTitle: "Restart",
                footer: "Score \(score)  •  Best combo \(bestCombo)",
                action: resetAll
            )
        case .freePlay:
            EmptyView()
        case .playing:
            EmptyView()
        }
    }

    private func startLevel() {
        if phase == .betweenLevels {
            currentLevelIndex = min(currentLevelIndex + 1, levels.count - 1)
        }
        arrows = []
        spawnAccumulator = 0
        spawnedInLevel = 0
        resolvedInLevel = 0
        combo = 0
        feedbackText = activeLevel.name
        phase = .playing
        spawnNextArrowIfNeeded()
    }

    private func resetAll() {
        arrows = []
        score = 0
        lives = GameTheme.maxLives
        currentLevelIndex = 0
        spawnAccumulator = 0
        spawnedInLevel = 0
        resolvedInLevel = 0
        combo = 0
        bestCombo = 0
        feedbackText = "Match arrows at the hit zone"
        phase = .start
    }

    private func startFreePlay() {
        arrows = []
        combo = 0
        feedbackText = "Free play"
        phase = .freePlay
    }

    private func triggerFreePlayPad(_ direction: ArrowDirection) {
        playDirectionSound(for: direction)
        feedbackText = direction.freePlayLabel
        activePads.insert(direction)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            activePads.remove(direction)
        }
    }

    private func updateGame(height: CGFloat, hitY: CGFloat) {
        guard phase == .playing else { return }

        let dt = GameTheme.tickInterval
        spawnAccumulator += dt

        if spawnedInLevel < activeLevel.arrowsToSpawn && spawnAccumulator >= activeLevel.spawnInterval {
            spawnAccumulator = 0
            spawnNextArrowIfNeeded()
        }

        for index in arrows.indices {
            arrows[index].y += CGFloat(activeLevel.speed) * dt
            if arrows[index].state != .normal {
                arrows[index].feedbackAge += dt
            }
        }

        let missLine = hitY + GameTheme.missOffset
        var idsToMiss: [UUID] = []
        for arrow in arrows where arrow.state == .normal && arrow.y > missLine {
            idsToMiss.append(arrow.id)
        }
        for id in idsToMiss {
            markMiss(id: id, message: "Miss")
        }

        arrows.removeAll {
            $0.y > height + 30 || ($0.state != .normal && $0.feedbackAge > GameTheme.feedbackHold)
        }

        if spawnedInLevel >= activeLevel.arrowsToSpawn
            && resolvedInLevel >= activeLevel.arrowsToSpawn
            && arrows.isEmpty {
            phase = lives > 0 ? .betweenLevels : .gameOver
            feedbackText = "Level Complete"
            WKInterfaceDevice.current().play(.success)
        }
    }

    private func judgeSwipe(_ swipe: ArrowDirection, hitY: CGFloat) {
        guard phase == .playing else { return }
        playDirectionSound(for: swipe)

        let candidates = arrows.enumerated().filter { $0.element.state == .normal }
        guard let nearest = candidates.min(by: { abs($0.element.y - hitY) < abs($1.element.y - hitY) }) else {
            registerWrong(message: "No arrow")
            return
        }

        let arrow = nearest.element
        let delta = abs(arrow.y - hitY)
        let judge = TimingJudge.judge(delta: delta)

        guard judge != .miss else {
            registerWrong(message: "Too early/late")
            return
        }

        if arrow.direction == swipe {
            arrows[nearest.offset].state = (judge == .perfect) ? .hitPerfect : .hitGood
            arrows[nearest.offset].feedbackAge = 0
            resolvedInLevel += 1
            score += 10
            combo += 1
            bestCombo = max(bestCombo, combo)
            feedbackText = judge.label
            showJudgePopup(judge)
            if combo >= 2 { showComboPopup("x\(combo)") }
        } else {
            markMiss(id: arrow.id, message: "Wrong way")
        }
    }

    private func markMiss(id: UUID, message: String) {
        guard let index = arrows.firstIndex(where: { $0.id == id }) else { return }
        guard arrows[index].state == .normal else { return }

        arrows[index].state = .miss
        arrows[index].feedbackAge = 0
        resolvedInLevel += 1
        registerWrong(message: message)
    }

    private func registerWrong(message: String) {
        lives -= 1
        combo = 0
        feedbackText = message
        showJudgePopup(.miss)

        if lives <= 0 {
            phase = .gameOver
        }
    }

    private func playDirectionSound(for direction: ArrowDirection) {
        DrumKitPlayer.shared.play(direction: direction)
    }

    private func spawnNextArrowIfNeeded() {
        guard spawnedInLevel < activeLevel.arrowsToSpawn else { return }
        let direction = activeLevel.pattern[spawnedInLevel % activeLevel.pattern.count]
        arrows.append(FallingArrow(direction: direction))
        spawnedInLevel += 1
    }

    private func showJudgePopup(_ judge: TimingJudge.Result) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            judgePopup = JudgePopup(text: judge.label, color: judge.color)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + GameTheme.popupDuration) {
            withAnimation(.easeOut(duration: 0.15)) {
                judgePopup = nil
            }
        }
    }

    private func showComboPopup(_ text: String) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            comboPopup = ComboPopup(text: text)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + GameTheme.popupDuration) {
            withAnimation(.easeOut(duration: 0.15)) {
                comboPopup = nil
            }
        }
    }

    private func swipeDirection(from translation: CGSize) -> ArrowDirection? {
        let dx = translation.width
        let dy = translation.height
        let threshold = GameTheme.swipeMinDistance
        guard abs(dx) > threshold || abs(dy) > threshold else { return nil }

        if abs(dx) > abs(dy) {
            return dx > 0 ? .right : .left
        }
        return dy > 0 ? .down : .up
    }
}

private struct ArrowChip: View {
    let arrow: FallingArrow

    var body: some View {
        ZStack {
            Circle()
                .fill(fillGradient)
                .frame(width: GameTheme.arrowChipSize, height: GameTheme.arrowChipSize)
                .shadow(color: glowColor.opacity(0.55), radius: 6, y: 2)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.34), lineWidth: 1.5)
                )

            Image(systemName: arrow.direction.symbolName)
                .font(.system(size: GameTheme.arrowSymbolSize, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .animation(.easeOut(duration: GameTheme.feedbackAnimDuration), value: arrow.state)
    }

    private var fillGradient: LinearGradient {
        switch arrow.state {
        case .normal:
            return LinearGradient(colors: [GameTheme.arrowTop, GameTheme.arrowBottom], startPoint: .top, endPoint: .bottom)
        case .hitPerfect:
            return LinearGradient(colors: [GameTheme.perfect, GameTheme.good], startPoint: .top, endPoint: .bottom)
        case .hitGood:
            return LinearGradient(colors: [GameTheme.good, GameTheme.ok], startPoint: .top, endPoint: .bottom)
        case .miss:
            return LinearGradient(colors: [GameTheme.miss, GameTheme.miss.opacity(0.6)], startPoint: .top, endPoint: .bottom)
        }
    }

    private var scale: CGFloat {
        switch arrow.state {
        case .normal: return 1.0
        case .hitPerfect: return 1.18
        case .hitGood: return 1.11
        case .miss: return 0.88
        }
    }

    private var opacity: Double {
        switch arrow.state {
        case .normal: return 1.0
        case .hitPerfect, .hitGood: return 1.0
        case .miss: return 0.7
        }
    }

    private var glowColor: Color {
        switch arrow.state {
        case .normal: return GameTheme.arrowGlow
        case .hitPerfect: return GameTheme.perfect
        case .hitGood: return GameTheme.good
        case .miss: return GameTheme.miss
        }
    }
}

private struct OverlayCard: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let footer: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: GameTheme.cardSpacing) {
            Text(title)
                .font(GameTheme.cardTitleFont)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text(subtitle)
                .font(GameTheme.cardSubtitleFont)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.86))

            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(GameTheme.primaryButton)

            Text(footer)
                .font(GameTheme.cardFooterFont)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(GameTheme.cardPadding)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GameTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: GameTheme.cardCornerRadius)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        .padding(.horizontal, 10)
    }
}

private struct StartMenuCard: View {
    let title: String
    let primaryButton: String
    let secondaryButton: String
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    var body: some View {
        VStack(spacing: GameTheme.cardSpacing) {
            Text(title)
                .font(GameTheme.cardTitleFont)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Button(primaryButton, action: primaryAction)
                .buttonStyle(.borderedProminent)
                .tint(GameTheme.primaryButton)

            Button(secondaryButton, action: secondaryAction)
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.8))
        }
        .padding(GameTheme.cardPadding)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GameTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: GameTheme.cardCornerRadius)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        .padding(.horizontal, 10)
    }
}

private struct FreePlayQuadrant: View {
    let title: String
    let color: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(color.opacity(isActive ? 0.98 : 0.82))
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 1)
        }
        .overlay(
            Rectangle()
                .stroke(.white.opacity(0.22), lineWidth: 0.8)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .animation(.easeOut(duration: 0.08), value: isActive)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FallingArrow: Identifiable {
    let id = UUID()
    let direction: ArrowDirection
    var y: CGFloat = -26
    var state: ArrowState = .normal
    var feedbackAge: Double = 0
}

private enum ArrowDirection: CaseIterable {
    case left
    case right
    case up
    case down

    var symbolName: String {
        switch self {
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        }
    }

    var freePlayLabel: String {
        switch self {
        case .right: return "Hi-hat"
        case .left: return "Snare"
        case .up: return "Crash"
        case .down: return "Kick"
        }
    }
}

private enum ArrowState {
    case normal
    case hitPerfect
    case hitGood
    case miss
}

private enum GamePhase {
    case start
    case playing
    case betweenLevels
    case gameOver
    case freePlay
}

private struct BeatLevel {
    let name: String
    let pattern: [ArrowDirection]
    let arrowsToSpawn: Int
    let spawnInterval: Double
    let speed: CGFloat
}

private enum TimingJudge {
    enum Result {
        case perfect
        case good
        case ok
        case miss

        var label: String {
            switch self {
            case .perfect: return "Perfect"
            case .good: return "Good"
            case .ok: return "OK"
            case .miss: return "Miss"
            }
        }

        var color: Color {
            switch self {
            case .perfect: return GameTheme.perfect
            case .good: return GameTheme.good
            case .ok: return GameTheme.ok
            case .miss: return GameTheme.miss
            }
        }
    }

    static func judge(delta: CGFloat) -> Result {
        if delta <= 12 { return .perfect }
        if delta <= 24 { return .good }
        if delta <= 34 { return .ok }
        return .miss
    }
}

private struct JudgePopup {
    let text: String
    let color: Color
}

private struct ComboPopup {
    let text: String
}

private enum GameTheme {
    static let maxLives = 5

    static let tickInterval: Double = 0.04
    static let feedbackHold: Double = 0.13
    static let popupDuration: Double = 0.45
    static let pulseDuration: Double = 1.0
    static let feedbackAnimDuration: Double = 0.14

    static let hitZoneYFactor: CGFloat = 0.58
    static let missOffset: CGFloat = 40
    static let swipeMinDistance: CGFloat = 14

    static let hitZoneHeight: CGFloat = 14
    static let arrowChipSize: CGFloat = 35
    static let arrowSymbolSize: CGFloat = 21
    static let cardPadding: CGFloat = 10
    static let cardCornerRadius: CGFloat = 12
    static let cardSpacing: CGFloat = 6
    static let hudHorizontalPadding: CGFloat = 8
    static let hudTopPadding: CGFloat = 6

    static let hudTitleFont: Font = .caption2.weight(.bold)
    static let hudSubFont: Font = .caption2
    static let cardTitleFont: Font = .headline.weight(.bold)
    static let cardSubtitleFont: Font = .caption2
    static let cardFooterFont: Font = .system(size: 10, weight: .medium, design: .rounded)

    static let bgTop = Color(red: 0.05, green: 0.08, blue: 0.15)
    static let bgBottom = Color(red: 0.02, green: 0.03, blue: 0.07)
    static let bgGlow = Color.cyan

    static let arrowTop = Color(red: 0.33, green: 0.67, blue: 1.0)
    static let arrowBottom = Color(red: 0.14, green: 0.36, blue: 0.92)
    static let arrowGlow = Color.cyan

    static let perfect = Color(red: 0.35, green: 0.98, blue: 0.62)
    static let good = Color(red: 0.24, green: 0.78, blue: 1.0)
    static let ok = Color(red: 0.95, green: 0.83, blue: 0.33)
    static let miss = Color(red: 1.0, green: 0.34, blue: 0.35)
    static let comboColor = Color(red: 1.0, green: 0.84, blue: 0.22)
    static let primaryButton = Color(red: 0.21, green: 0.52, blue: 1.0)

    static let hitZoneFill = Color.white.opacity(0.08)
    static let hitZoneStroke = Color.white.opacity(0.75)
    static let hitZoneDash = Color.white.opacity(0.7)
    static let hitZoneGlow = Color.cyan

    static let padHihat = Color(red: 0.22, green: 0.63, blue: 1.0)
    static let padSnare = Color(red: 0.89, green: 0.34, blue: 0.36)
    static let padKick = Color(red: 0.25, green: 0.79, blue: 0.45)
    static let padCrash = Color(red: 1.0, green: 0.74, blue: 0.26)
}

private final class DrumKitPlayer {
    static let shared = DrumKitPlayer()

    private var playerPools: [ArrowDirection: [AVAudioPlayer]] = [:]
    private var roundRobinIndex: [ArrowDirection: Int] = [:]
    private var didWarmUp = false

    private init() {}

    func warmUp() {
        guard !didWarmUp else { return }
        didWarmUp = true

        configureAudioSession()
        playerPools[.right] = loadPool(named: "hihat")
        playerPools[.left] = loadPool(named: "snare")
        playerPools[.up] = loadPool(named: "crash")
        playerPools[.down] = loadPool(named: "kick")
        roundRobinIndex[.right] = 0
        roundRobinIndex[.left] = 0
        roundRobinIndex[.up] = 0
        roundRobinIndex[.down] = 0
    }

    func play(direction: ArrowDirection) {
        guard var pool = playerPools[direction], !pool.isEmpty else { return }

        if let idleIndex = pool.firstIndex(where: { !$0.isPlaying }) {
            let player = pool[idleIndex]
            player.currentTime = 0
            player.play()
            return
        }

        let next = roundRobinIndex[direction, default: 0] % pool.count
        roundRobinIndex[direction] = (next + 1) % pool.count
        pool[next].currentTime = 0
        pool[next].play()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Ignore audio-session failures; haptics still work.
        }
    }

    private func loadPool(named: String) -> [AVAudioPlayer] {
        var pool: [AVAudioPlayer] = []
        for _ in 0..<3 {
            if let p = loadPlayer(named: named) {
                pool.append(p)
            }
        }
        return pool
    }

    private func loadPlayer(named: String) -> AVAudioPlayer? {
        let candidates = ["wav", "mp3", "m4a", "aif", "caf"]
        guard let url = candidates.compactMap({ Bundle.main.url(forResource: named, withExtension: $0) }).first else {
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.volume = 1.0
            return player
        } catch {
            return nil
        }
    }
}

#Preview {
    ContentView()
}
