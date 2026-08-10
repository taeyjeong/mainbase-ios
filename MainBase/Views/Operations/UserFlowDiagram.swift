import SwiftUI

/// User-flow view: each app screen is drawn as a small phone-screen card and the navigation paths
/// between them are drawn as labeled, arrowed connectors. Static sample data — the sign-in / home /
/// detail flow of a typical app.
struct UserFlowDiagram: View {
    private let screens = UserFlowSample.screens
    private let edges = UserFlowSample.edges

    private let canvasSize = CGSize(width: 650, height: 400)
    private let lineColor = AppColors.primary.opacity(0.6)

    private func screen(_ id: String) -> AppScreen { screens.first { $0.id == id }! }

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                heading
                diagram
            }
            .padding(20)
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Onboarding User Flow")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.text)
            Text("How a new user moves from launch to their first project")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private var diagram: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for edge in edges {
                    let from = screen(edge.from).rect
                    let to = screen(edge.to).rect
                    let connector = DiagramConnector(from: anchor(of: from, toward: to.centerPoint),
                                                     to: anchor(of: to, toward: from.centerPoint),
                                                     axis: edge.axis)
                    DiagramDraw.arrow(&context, connector, color: lineColor, lineWidth: 2)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)

            ForEach(edges) { edge in
                let from = screen(edge.from).rect
                let to = screen(edge.to).rect
                let connector = DiagramConnector(from: anchor(of: from, toward: to.centerPoint),
                                                 to: anchor(of: to, toward: from.centerPoint),
                                                 axis: edge.axis)
                Text(edge.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(AppColors.background))
                    .overlay(Capsule().stroke(AppColors.primary.opacity(0.3), lineWidth: 1))
                    .position(connector.labelPoint(backBy: 34))
            }

            ForEach(screens) { screen in
                screenCard(screen).position(screen.center)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    /// Picks the edge anchor (leading/trailing/top/bottom) of `rect` that faces `target`, so a
    /// connector leaves and arrives on the sides that face each other.
    private func anchor(of rect: CGRect, toward target: CGPoint) -> CGPoint {
        let dx = target.x - rect.midX
        let dy = target.y - rect.midY
        if abs(dx) > abs(dy) {
            return dx >= 0 ? rect.trailingAnchor : rect.leadingAnchor
        } else {
            return dy >= 0 ? rect.bottomAnchor : rect.topAnchor
        }
    }

    private func screenCard(_ screen: AppScreen) -> some View {
        VStack(spacing: 0) {
            // Title bar, tinted per screen role.
            HStack(spacing: 5) {
                Image(systemName: screen.icon).font(.system(size: 10, weight: .semibold))
                Text(screen.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(screen.tint)

            // Skeleton "content" so it reads as a screen mock.
            VStack(alignment: .leading, spacing: 7) {
                RoundedRectangle(cornerRadius: 4).fill(screen.tint.opacity(0.18)).frame(height: 26)
                RoundedRectangle(cornerRadius: 3).fill(AppColors.border).frame(height: 8)
                RoundedRectangle(cornerRadius: 3).fill(AppColors.border).frame(width: 70, height: 8)
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 5).fill(screen.tint.opacity(0.5)).frame(height: 18)
            }
            .padding(10)
        }
        .frame(width: screen.size.width, height: screen.size.height)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1.5))
    }
}

/// A single app screen node in the user flow.
struct AppScreen: Identifiable {
    let id: String
    let title: String
    let icon: String
    let tint: Color
    let center: CGPoint

    var size: CGSize { CGSize(width: 120, height: 150) }
    var rect: CGRect { CGRect(center: center, size: size) }
}

/// A navigation path between two screens, with the action that triggers it.
struct UserFlowEdge: Identifiable {
    let id = UUID()
    let from: String
    let to: String
    let label: String
    var axis: Axis = .horizontal
}

/// Static sample data for the user-flow diagram.
enum UserFlowSample {
    private static let authTint = Color(hex: "#5856D6")
    private static let mainTint = AppColors.primary
    private static let neutralTint = Color(hex: "#8E8E93")

    static let screens: [AppScreen] = [
        AppScreen(id: "splash", title: "Splash", icon: "sparkles", tint: neutralTint, center: CGPoint(x: 75, y: 188)),
        AppScreen(id: "signin", title: "Sign In", icon: "lock", tint: authTint, center: CGPoint(x: 235, y: 95)),
        AppScreen(id: "signup", title: "Sign Up", icon: "person.badge.plus", tint: authTint, center: CGPoint(x: 235, y: 300)),
        AppScreen(id: "home", title: "Home", icon: "house", tint: mainTint, center: CGPoint(x: 395, y: 188)),
        AppScreen(id: "detail", title: "Project", icon: "folder", tint: mainTint, center: CGPoint(x: 555, y: 95)),
        AppScreen(id: "profile", title: "Profile", icon: "person", tint: mainTint, center: CGPoint(x: 555, y: 300)),
    ]

    static let edges: [UserFlowEdge] = [
        UserFlowEdge(from: "splash", to: "signin", label: "Launch"),
        UserFlowEdge(from: "signin", to: "signup", label: "Create account", axis: .vertical),
        UserFlowEdge(from: "signin", to: "home", label: "Log in"),
        UserFlowEdge(from: "signup", to: "home", label: "Register"),
        UserFlowEdge(from: "home", to: "detail", label: "Open project"),
        UserFlowEdge(from: "home", to: "profile", label: "Account"),
    ]
}

#Preview {
    UserFlowDiagram()
        .background(AppColors.background)
}
