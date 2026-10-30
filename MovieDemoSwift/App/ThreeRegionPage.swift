import SwiftUI

struct ThreeRegionPage<Header: View, Page: View, Footer: View>: View {
    let isHeaderVisible: Bool
    let isPageContentVisible: Bool
    let isFooterVisible: Bool
    @ViewBuilder let headerContent: () -> Header
    @ViewBuilder let pageContent: () -> Page
    @ViewBuilder let footerContent: () -> Footer

    init(
        isHeaderVisible: Bool = true,
        isPageContentVisible: Bool = true,
        isFooterVisible: Bool = true,
        @ViewBuilder headerContent: @escaping () -> Header,
        @ViewBuilder pageContent: @escaping () -> Page,
        @ViewBuilder footerContent: @escaping () -> Footer
    ) {
        self.isHeaderVisible = isHeaderVisible
        self.isPageContentVisible = isPageContentVisible
        self.isFooterVisible = isFooterVisible
        self.headerContent = headerContent
        self.pageContent = pageContent
        self.footerContent = footerContent
    }

    var body: some View {
        VStack(spacing: 0) {
            if isHeaderVisible {
                headerContent()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                Divider()
            }
            if isPageContentVisible {
                pageContent()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
            }
            if isFooterVisible {
                Divider()
                footerContent()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
    }
}
