import SwiftUI

// Simple replacement for HFlow to avoid SwiftUI-Flow Swift 6 compatibility issues
struct HFlow<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content
    
    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        _HFlowLayout(spacing: spacing) {
            content()
        }
    }
}

// Internal layout implementation
private struct _HFlowLayout<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content
    
    var body: some View {
        GeometryReader { geometry in
            _HFlowLayoutView(spacing: spacing, availableWidth: geometry.size.width) {
                content()
            }
        }
    }
}

private struct _HFlowLayoutView<Content: View>: View {
    let spacing: CGFloat
    let availableWidth: CGFloat
    let content: () -> Content
    
    var body: some View {
        _HFlowLayoutContainer(spacing: spacing, availableWidth: availableWidth) {
            content()
        }
    }
}

private struct _HFlowLayoutContainer<Content: View>: View {
    let spacing: CGFloat
    let availableWidth: CGFloat
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            _HFlowRowLayout(spacing: spacing, availableWidth: availableWidth) {
                content()
            }
        }
    }
}

private struct _HFlowRowLayout<Content: View>: View {
    let spacing: CGFloat
    let availableWidth: CGFloat
    let content: () -> Content
    
    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
