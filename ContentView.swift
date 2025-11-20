import SwiftUI

struct ContentView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var cfg: LayoutConfig

    // Fixed zone sizes (points) as specified (landscape, notch on the left)
    private let mgzSize = CGSize(width: 782, height: 393) // W x H when device is landscape-left; spec lists 393 x 782; we’ll place using orientation-aware axes
    private let mgzOffsetFromLeft: CGFloat = 55

    private let lzSize = CGSize(width: 135, height: 393)
    private let tzSize = CGSize(width: 662, height: 70)
    private let czSize = CGSize(width: 512, height: 323)
    private let rzSize = CGSize(width: 135, height: 323)

    // Centering/scaling controls
    private let enableCentering: Bool = true
    private let enableScaling: Bool = true
    private let maxScale: CGFloat = 1.3
    private let horizontalMargin: CGFloat = 16
    private let verticalMargin: CGFloat = 12

    var body: some View {
        ZStack {
            // Force the bg image as the background
            GeometryReader { geo in
                Image("bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            if game.phase == .preGame {
                PreGameView()
                    .environmentObject(game)
                    .environmentObject(cfg)
                    .transition(.opacity)
            } else {
                GeometryReader { proxy in
                    // Compute centering and optional scale
                    let containerSize = proxy.size
                    let targetSize = mgzSize

                    // Available space after margins
                    let availW = max(0, containerSize.width - (enableCentering ? 2 * horizontalMargin : 0))
                    let availH = max(0, containerSize.height - (enableCentering ? 2 * verticalMargin : 0))

                    // Fit uniform scale if enabled
                    let fitScale: CGFloat = {
                        guard enableScaling else { return 1.0 }
                        guard targetSize.width > 0, targetSize.height > 0 else { return 1.0 }
                        let sW = availW / targetSize.width
                        let sH = availH / targetSize.height
                        let s = min(sW, sH)
                        return min(max(s, 1.0), maxScale) // never shrink below 1.0; cap growth
                    }()

                    // Positioning
                    let centerX = containerSize.width / 2
                    let centerY = containerSize.height / 2

                    // Treat coordinate system as landscape-left if not centering
                    let mgzOrigin = CGPoint(x: mgzOffsetFromLeft, y: 0)

                    ZStack {
                        // Board layer within MGZ: LZ, TZ, CZ, RZ
                        BoardView(
                            mgzSize: mgzSize,
                            lzSize: lzSize,
                            tzSize: tzSize,
                            czSize: czSize,
                            rzSize: rzSize
                        )
                        .environmentObject(game)
                        .environmentObject(cfg)
                        .allowsHitTesting(!showingOverlay)
                        .blur(radius: showingOverlay ? 1.0 : 0)

                        // Overlay layer centered within MGZ
                        if showingOverlay {
                            // Dimmed background over board
                            LinearGradient(
                                colors: [Color.black.opacity(0.55), Color.black.opacity(0.35)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea()
                            .transition(.opacity)

                            // Full-frame interstitial that lives inside the MGZ frame
                            InterstitialOverlay()
                                .environmentObject(game)
                                .environmentObject(cfg)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 18)
                                .transition(.scale.combined(with: .opacity))
                                .zIndex(1)
                        }
                    }
                    .frame(width: mgzSize.width, height: mgzSize.height, alignment: .topLeading)
                    .scaleEffect(fitScale, anchor: .center)
                    .position(
                        x: enableCentering ? centerX : (mgzOrigin.x + mgzSize.width / 2),
                        y: enableCentering ? centerY : (mgzOrigin.y + mgzSize.height / 2)
                    )
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: showingOverlay)
        .ignoresSafeArea()
    }

    // MARK: - Derived
    private var showingOverlay: Bool {
        game.phase == .betweenRounds || game.phase == .gameOver
    }
}
