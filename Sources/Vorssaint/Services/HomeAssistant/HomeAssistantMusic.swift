// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine

/// Home Assistant media players as sources of the island's music page. A
/// chosen player stays shown while paused; left to the island, a playing
/// Home Assistant player is shown only while nothing plays on this Mac.
final class HomeAssistantMusic: ObservableObject {
    static let shared = HomeAssistantMusic()

    /// The players worth offering: on, available, playing ones first.
    @Published private(set) var players: [HomeAssistantMediaPlayer] = []
    /// The player the music page shows instead of this Mac's playback.
    @Published private(set) var active: HomeAssistantMediaPlayer?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var artworkTint: NotchArtworkTint?
    @Published private(set) var selection: String?

    private let home = HomeAssistantService.shared
    private let defaults: UserDefaults
    private let surface = UUID()
    private var subscriptions: Set<AnyCancellable> = []
    private var artworkURL: URL?
    private var artworkTask: Task<Void, Never>?

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.string(forKey: DefaultsKey.notchHomeAssistantMusicPlayer) ?? ""
        selection = saved.hasPrefix("media_player.") ? saved : nil
        // objectWillChange fires before the store mutates; read on the next turn.
        home.objectWillChange.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        NotchMusicService.shared.$playback.map { $0?.isPlaying == true }.removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        refresh()
    }

    var connected: Bool { home.connection == .connected }

    /// Keeps the Home Assistant connection open while the music page shows.
    func setVisible(_ visible: Bool) {
        guard home.enabled else { return }
        home.setVisible(visible, surface: surface)
    }

    /// Nil returns the choice to the island.
    func select(_ id: String?) {
        selection = id
        defaults.set(id ?? "", forKey: DefaultsKey.notchHomeAssistantMusicPlayer)
        refresh()
    }

    func perform(_ service: String, data: [String: HomeAssistantValue] = [:], on id: String? = nil) {
        guard let target = id ?? active?.id else { return }
        home.perform(service, entityID: target, data: data)
    }

    func isPending(_ id: String) -> Bool { home.pending.contains(id) }

    private func refresh() {
        let all = home.enabled ? home.entities.values.compactMap(HomeAssistantMediaPlayer.init) : []
        let offered = all.filter(\.isActive).sorted {
            $0.isPlaying != $1.isPlaying ? $0.isPlaying : $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        if offered != players { players = offered }
        let next = HomeAssistantMediaPlayer.choose(selection: selection, players: all,
                               macPlaying: NotchMusicService.shared.playback?.isPlaying == true)
        if next != active { active = next }
        loadArtwork(next?.pictureURL(base: home.dashboardURL))
    }

    private func loadArtwork(_ url: URL?) {
        guard url != artworkURL else { return }
        artworkURL = url
        artworkTask?.cancel()
        guard let url else { artwork = nil; artworkTint = nil; return }
        artworkTask = Task { @MainActor [weak self] in
            // ponytail: no cache, HA's proxy URL changes per track and the island shows one cover.
            let loaded = try? await URLSession.shared.data(from: url)
            guard !Task.isCancelled, let self, self.artworkURL == url else { return }
            guard let (data, response) = loaded, (response as? HTTPURLResponse)?.statusCode ?? 200 < 300,
                  let image = ImageThumbnailer.thumbnail(data: data, pointSize: 160, scale: 2) else {
                self.artwork = nil; self.artworkTint = nil; return
            }
            self.artwork = image
            self.artworkTint = NotchMusicService.artworkTint(of: image)
        }
    }
}
