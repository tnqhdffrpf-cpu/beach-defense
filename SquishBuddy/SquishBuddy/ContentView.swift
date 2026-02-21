import SwiftUI

struct ContentView: View {
    @State private var phase: TrickPhase = .selection
    @State private var secondsLeft = 5
    @State private var selectionProgress: Double = 1.0

    @State private var shuffleJitter = false
    @State private var removedCardOpacity: Double = 1
    @State private var removedCardScale: CGFloat = 1

    @State private var revealFaceUp: [Bool] = Array(repeating: false, count: 5)

    @State private var sequenceTask: Task<Void, Never>?

    private let openingCards: [PlayingCard] = [
        .init(rank: "K", suit: .hearts),
        .init(rank: "7", suit: .spades),
        .init(rank: "Q", suit: .diamonds),
        .init(rank: "A", suit: .clubs),
        .init(rank: "10", suit: .hearts),
        .init(rank: "4", suit: .spades)
    ]

    // Important: none of these are exact matches from openingCards.
    private let revealCards: [PlayingCard] = [
        .init(rank: "K", suit: .diamonds),
        .init(rank: "7", suit: .clubs),
        .init(rank: "Q", suit: .hearts),
        .init(rank: "A", suit: .spades),
        .init(rank: "10", suit: .clubs)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.08, blue: 0.14), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                header

                switch phase {
                case .selection:
                    selectionView
                case .shuffle:
                    shuffleView
                case .reveal:
                    revealView
                }
            }
            .padding()
        }
        .onAppear {
            startTrick()
        }
        .onDisappear {
            sequenceTask?.cancel()
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Mind Reader Cards")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .minimumScaleFactor(0.75)

            Text(subtitle)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
    }

    private var subtitle: String {
        switch phase {
        case .selection:
            return "Think of one card and lock it in."
        case .shuffle:
            return "I will remove the card you're thinking of..."
        case .reveal:
            return "I read your mind."
        }
    }

    private var selectionView: some View {
        VStack(spacing: 14) {
            Text("\(secondsLeft)")
                .font(.system(size: 50, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow)

            ProgressView(value: selectionProgress)
                .tint(.yellow)
                .frame(maxWidth: 320)

            cardGrid(cards: openingCards, faceUp: Array(repeating: true, count: openingCards.count))
        }
    }

    private var shuffleView: some View {
        VStack(spacing: 16) {
            ZStack {
                ForEach(openingCards.indices, id: \.self) { index in
                    let isRemoved = index == 2
                    BackCardView()
                        .frame(width: 90, height: 128)
                        .rotationEffect(.degrees(Double(index * 6) + (shuffleJitter ? Double((index % 2 == 0 ? 1 : -1) * 5) : 0)))
                        .offset(x: CGFloat(index - 2) * 10, y: CGFloat((index % 2) * 4))
                        .scaleEffect(isRemoved ? removedCardScale : 1)
                        .opacity(isRemoved ? removedCardOpacity : 1)
                        .animation(.easeInOut(duration: 0.22).repeatForever(autoreverses: true), value: shuffleJitter)
                }
            }
            .frame(height: 170)

            Text("Shuffling...")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var revealView: some View {
        VStack(spacing: 14) {
            cardGrid(cards: revealCards, faceUp: revealFaceUp)

            Text("Your card is gone.")
                .font(.title3.bold())
                .foregroundStyle(.green)

            Button("Do It Again") {
                resetAndRestart()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func cardGrid(cards: [PlayingCard], faceUp: [Bool]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 12)], spacing: 12) {
            ForEach(cards.indices, id: \.self) { index in
                CardFlipView(card: cards[index], isFaceUp: faceUp[index])
                    .frame(width: 90, height: 128)
            }
        }
    }

    private func resetAndRestart() {
        sequenceTask?.cancel()
        phase = .selection
        secondsLeft = 5
        selectionProgress = 1
        shuffleJitter = false
        removedCardOpacity = 1
        removedCardScale = 1
        revealFaceUp = Array(repeating: false, count: revealCards.count)
        startTrick()
    }

    private func startTrick() {
        sequenceTask?.cancel()
        sequenceTask = Task {
            await runSelectionPhase()
            guard !Task.isCancelled else { return }
            await runShufflePhase()
            guard !Task.isCancelled else { return }
            await runRevealPhase()
        }
    }

    @MainActor
    private func runSelectionPhase() async {
        phase = .selection
        secondsLeft = 5
        selectionProgress = 1
        for remaining in stride(from: 5, through: 1, by: -1) {
            secondsLeft = remaining
            selectionProgress = Double(remaining) / 5.0
            try? await Task.sleep(for: .seconds(1))
        }
    }

    @MainActor
    private func runShufflePhase() async {
        phase = .shuffle
        shuffleJitter = true

        try? await Task.sleep(for: .seconds(1.2))

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            removedCardScale = 0.01
            removedCardOpacity = 0
        }

        try? await Task.sleep(for: .seconds(1.0))
        shuffleJitter = false
    }

    @MainActor
    private func runRevealPhase() async {
        phase = .reveal
        revealFaceUp = Array(repeating: false, count: revealCards.count)

        for index in revealCards.indices {
            withAnimation(.easeInOut(duration: 0.28)) {
                revealFaceUp[index] = true
            }
            try? await Task.sleep(for: .seconds(0.32))
        }
    }
}

private enum TrickPhase {
    case selection
    case shuffle
    case reveal
}

private struct CardFlipView: View {
    let card: PlayingCard
    let isFaceUp: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.black.opacity(0.12), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.rank)
                            .font(.headline.bold())
                        Text(card.suit.symbol)
                            .font(.subheadline)
                    }
                    .foregroundStyle(card.suit.color)
                    .padding(8)
                }
                .overlay {
                    Text(card.suit.symbol)
                        .font(.system(size: 34))
                        .foregroundStyle(card.suit.color)
                }
                .opacity(isFaceUp ? 1 : 0)

            BackCardView()
                .opacity(isFaceUp ? 0 : 1)
        }
        .rotation3DEffect(.degrees(isFaceUp ? 0 : 180), axis: (x: 0, y: 1, z: 0))
    }
}

private struct BackCardView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.7), lineWidth: 1.5)
            )
            .overlay {
                Image(systemName: "sparkles")
                    .font(.title.bold())
                    .foregroundStyle(.white.opacity(0.85))
            }
    }
}

private struct PlayingCard {
    let rank: String
    let suit: Suit
}

private enum Suit {
    case hearts
    case diamonds
    case clubs
    case spades

    var symbol: String {
        switch self {
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .clubs: return "♣"
        case .spades: return "♠"
        }
    }

    var color: Color {
        switch self {
        case .hearts, .diamonds: return .red
        case .clubs, .spades: return .black
        }
    }
}

#Preview {
    ContentView()
}
