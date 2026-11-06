import AVKit
import SwiftUI
import UIKit

struct MovieDetailsPage: View {
    @StateObject private var viewModel: MovieDetailsViewModel
    @State private var isShareSheetPresented = false

    init(movie: Movie, container: AppContainer) {
        _viewModel = StateObject(
            wrappedValue: MovieDetailsViewModel(
                movie: movie,
                movieRepository: container.movieRepository,
                trailerRepository: container.trailerRepository,
                favoriteRepository: container.favoriteRepository
            )
        )
    }

    var body: some View {
        ThreeRegionPage(
            isFooterVisible: viewModel.errorMessage != nil,
            headerContent: {
                Text(viewModel.movie.title).font(.title2).bold()
                    .accessibilityIdentifier("movie.details.\(viewModel.movie.id)")
            },
            pageContent: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(viewModel.movie.overview.isEmpty ? "No overview available." : viewModel.movie.overview)
                        HStack {
                            Button(viewModel.isFavorite ? "Remove favorite" : "Add favorite") {
                                Task { await viewModel.toggleFavorite() }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isUpdatingFavorite)
                            .accessibilityIdentifier("movie.favorite.toggle")

                            Button {
                                isShareSheetPresented = true
                            } label: {
                                Label("Share movie", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                        }
                        Text("Trailer").font(.headline)

                        switch viewModel.trailerPlaybackState {
                        case .idle, .loading:
                            ProgressView("Loading trailer…")
                        case .playable(let trailerMedia):
                            NativeTrailerPlayer(sourceURL: trailerMedia.sourceURL)
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text("Preview provided by \(trailerMedia.providerName).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let providerPageURL = URL(string: trailerMedia.providerPageURL) {
                                Link("View this movie on Apple TV", destination: providerPageURL)
                                    .font(.caption)
                            }
                        case .externalOnly(let externalURL):
                            Text("A direct preview is unavailable, but TMDB found a YouTube trailer.")
                                .foregroundStyle(.secondary)
                            if let destination = URL(string: externalURL) {
                                Link("Open trailer on YouTube", destination: destination)
                                    .buttonStyle(.bordered)
                            }
                        case .unavailable:
                            Text("No playable trailer is available.")
                                .foregroundStyle(.secondary)
                        case .failed(let message):
                            Text(message)
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            },
            footerContent: { Text(viewModel.errorMessage ?? "") }
        )
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShareSheetPresented) {
            MovieShareSheet(message: shareMessage)
        }
        .task { await viewModel.load() }
    }

    private var shareMessage: String {
        let movie = viewModel.movie
        return movie.overview.isEmpty ? movie.title : "\(movie.title)\n\n\(movie.overview)"
    }
}

private struct MovieShareSheet: UIViewControllerRepresentable {
    let message: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [message], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

@MainActor
private final class NativeTrailerPlayerController: ObservableObject {
    let player = AVPlayer()
    private var loadedSourceURL: String?

    func load(sourceURL: String) {
        guard loadedSourceURL != sourceURL, let url = URL(string: sourceURL) else {
            return
        }
        loadedSourceURL = sourceURL
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        loadedSourceURL = nil
    }
}

private struct NativeTrailerPlayer: View {
    let sourceURL: String
    @StateObject private var controller = NativeTrailerPlayerController()

    var body: some View {
        VideoPlayer(player: controller.player)
            .background(Color.black)
            .onAppear {
                controller.load(sourceURL: sourceURL)
            }
            .onChange(of: sourceURL) { _, newSourceURL in
                controller.load(sourceURL: newSourceURL)
            }
            .onDisappear {
                controller.stop()
            }
            .accessibilityLabel("Movie trailer player")
    }
}
