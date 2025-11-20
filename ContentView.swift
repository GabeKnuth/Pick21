import SwiftUI

struct ContentView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var cfg: LayoutConfig

    // Fixed zone sizes (points) as specified for MGZ
    private let mgzSize = CGSize(width: 782, height: 393)
    private let mgzOffsetFromLeft: CGFloat = 55

    private let lzSize = CGSize(width: 135, height: 393)
    private let tzSize = CGSize(width: 662, height: 70)
    private let czSize = CGSize(width: 512, height: 323)
    private let rzSize = CGSize(width: 135, height: 323)

    // Centering/scaling controls
    private let enableCentering: Bool = true
    private let enableScaling: Bool = true
    private let maxScale: CGFloat = 1.3

    // Margins inside our effective safe area (keep 0 for now during smoke tests)
    private let horizontalMargin: CGFloat = 0
    private let verticalMargin: CGFloat = 0

    var body: some View {
        ZStack {
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
                    let fullSize = proxy.size
                    let sys = proxy.safeAreaInsets

                    let isLandscape = fullSize.width > fullSize.height
                    #if os(iOS)
                    let isPad = UIDevice.current.userInterfaceIdiom == .pad
                    #else
                    let isPad = false
                    #endif

                    // Determine notch side using interface orientation (new API when available).
                    // Returns true when the notch is on the "leading" side of the layout.
                    let notchOnLeading: Bool = {
                        #if os(iOS)
                        guard isLandscape, !isPad else { return false }

                        // Get the first active window scene
                        guard let windowScene = UIApplication.shared
                            .connectedScenes
                            .compactMap({ $0 as? UIWindowScene })
                            .first
                        else {
                            // Fallback: infer from insets
                            return sys.leading >= sys.trailing
                        }

                        // Prefer the modern API on newer SDKs
                        if #available(iOS 18.0, *) {
                            switch windowScene.effectiveGeometry.interfaceOrientation {
                            case .landscapeLeft:
                                // Notch on device's left edge => leading (LTR)
                                return true
                            case .landscapeRight:
                                // Notch on device's right edge => trailing (LTR)
                                return false
                            default:
                                break
                            }
                        } else {
                            // Fallback for older iOS
                            switch windowScene.interfaceOrientation {
                            case .landscapeLeft:
                                return true
                            case .landscapeRight:
                                return false
                            default:
                                break
                            }
                        }

                        // Last-resort fallback
                        return sys.leading >= sys.trailing
                        #else
                        return false
                        #endif
                    }()

                    // Build effective insets that primarily avoid the notch side on iPhone landscape.
                    let effective: EdgeInsets = {
                        if isPad || !isLandscape {
                            return sys
                        } else {
                            // Explicit values (override system)
                            let notchSide: CGFloat = 10   // room on notch side
                            let farSide: CGFloat = 1      // small on far side
                            let topSide: CGFloat = 1      // small at top
                            let bottomSide: CGFloat = 1   // small above home indicator

                            let lead = notchOnLeading ? notchSide : farSide
                            let trail = notchOnLeading ? farSide : notchSide

                            return EdgeInsets(top: topSide, leading: lead, bottom: bottomSide, trailing: trail)
                        }
                    }()

                    // Compute effective safe rect
                    let safeX = effective.leading
                    let safeY = effective.top
                    let safeW = max(0, fullSize.width - effective.leading - effective.trailing)
                    let safeH = max(0, fullSize.height - effective.top - effective.bottom)

                    // Apply optional margins
                    let paddedX = safeX + (enableCentering ? horizontalMargin : 0)
                    let paddedY = safeY + (enableCentering ? verticalMargin : 0)
                    let paddedW = max(0, safeW - (enableCentering ? 2 * horizontalMargin : 0))
                    let paddedH = max(0, safeH - (enableCentering ? 2 * verticalMargin : 0))

                    // Target MGZ size and fit scale
                    let targetW = mgzSize.width
                    let targetH = mgzSize.height
                    let fitScale: CGFloat = {
                        guard enableScaling, targetW > 0, targetH > 0, paddedW > 0, paddedH > 0 else { return 1.0 }
                        let sW = paddedW / targetW
                        let sH = paddedH / targetH
                        return min(min(sW, sH), maxScale)
                    }()

                    let centerX = paddedX + paddedW / 2
                    let centerY = paddedY + paddedH / 2

                    let mgzOrigin = CGPoint(x: mgzOffsetFromLeft, y: 0)

                    ZStack {
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

                        // MGZ red border (smoke test)
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red, lineWidth: 2)
                            .allowsHitTesting(false)

                        if showingOverlay {
                            LinearGradient(
                                colors: [Color.black.opacity(0.55), Color.black.opacity(0.35)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea()
                            .transition(.opacity)

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

                    // Yellow dashed border for effective padded area (smoke test)
                    Path { path in
                        let rect = CGRect(x: paddedX, y: paddedY, width: paddedW, height: paddedH)
                        path.addRect(rect)
                    }
                    .stroke(Color.yellow, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .allowsHitTesting(false)
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: showingOverlay)
        .ignoresSafeArea(edges: [])
    }

    private var showingOverlay: Bool {
        game.phase == .betweenRounds || game.phase == .gameOver
    }
}
