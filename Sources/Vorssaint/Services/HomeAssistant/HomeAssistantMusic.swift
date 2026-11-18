// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine

/// Home Assistant media players as sources of the island's music surfaces. A
/// chosen player stays shown while paused; left to the island, a playing
/// Home Assistant player is shown only while nothing plays on this Mac.
/// The speaker also takes the collapsed island: its playback is handed to
/// NotchMusicService in place of this Mac's, with commands routed back here.
final class HomeAssistantMusic: ObservableObject {
    static let shared = HomeAssistantMusic()

    /// The players worth offering: on, available, playing ones first.
    @Published private(set) var players: [HomeAssistantMediaPlayer] = []
    /// The player the music page shows instead of this Mac's playback.
    @Published private(set) var active: HomeAssistantMediaPlayer?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var artworkTint: NotchArtworkTint?
    @Published private(set) var selection: String?
    /// Music Assistant's current and next entry; nil until read, or when the player has no queue.
    @Published private(set) var upNext: (current: HomeAssistantQueueItem?, next: HomeAssistantQueueItem?)?
    @Published private(set) var queueLoading = false
    /// Music Assistant favorites by media type; a missing type is not read yet, an empty one has none.
    @Published private(set) var favorites: [String: [HomeAssistantLibraryItem]] = [:]
    @Published private(set) var favoritesUnavailable = false

    private let home = HomeAssistantService.shared
    private let defaults: UserDefaults
    private let surface = UUID()
    private var subscriptions: Set<AnyCancellable> = []
    private var artworkURL: URL?
    private var artworkTask: Task<Void, Never>?
    private var queueTask: Task<Void, Never>?
    private let music = NotchMusicService.shared

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.string(forKey: DefaultsKey.notchHomeAssistantMusicPlayer) ?? ""
        selection = saved.hasPrefix("media_player.") ? saved : nil
        // objectWillChange fires before the store mutates; read on the next turn.
        home.objectWillChange.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        // A reading from this Mac replaced or ended: decide again, after it is stored.
        music.$playback.filter { $0?.isHomeAssistant != true }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        music.homeCommand = { [weak self] in self?.send($0) ?? false }
        music.homeAllows = { [weak self] in self?.allows($0) ?? false }
        // The collapsed island follows a speaker without the page open, so the
        // connection stays up while Home Assistant is enabled and the Mac awake.
        // ponytail: one idle WebSocket; drop this surface if that ever matters.
        home.setVisible(true, surface: surface)
        refresh()
    }

    var connected: Bool { home.connection == .connected }

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
                               macPlaying: music.macPlayback?.isPlaying == true)
        if next?.id != active?.id { upNext = nil; queueTask?.cancel(); queueLoading = false }
        if next != active { active = next }
        loadArtwork(next?.pictureURL(base: home.dashboardURL))
        showOnIsland()
    }

    /// Hands the speaker to every music surface, or gives them back to this Mac.
    private func showOnIsland() {
        guard let player = active, player.hasMedia else { music.showHome(nil, artwork: nil, tint: nil); return }
        music.showHome(Self.playback(of: player), artwork: artwork, tint: artworkTint)
    }

    static func playback(of player: HomeAssistantMediaPlayer) -> NotchPlayback {
        let track = RadialNowPlayingSnapshot(title: player.title, artist: player.artist ?? player.name, album: player.album,
                                             artworkData: nil,
                                             appBundleIdentifier: NotchPlayback.homeAssistantPrefix + player.id, appPID: nil)
        let updated = player.updatedAt
        return NotchPlayback(track: track, isPlaying: player.isPlaying,
                             elapsed: max(0, player.entity.attributes["media_position"]?.number ?? 0),
                             duration: player.duration, rate: updated == nil ? 0 : 1,
                             sampledAt: updated ?? Date(timeIntervalSince1970: 0),
                             canSeek: player.supports(.seek), hasPosition: updated != nil,
                             itemIdentifier: player.entity.attributes["media_content_id"]?.string,
                             canSendCommandsDirectly: true,
                             canSkipNext: player.supports(.next), canSkipPrevious: player.supports(.previous))
    }

    private static func service(for command: NotchPlaybackCommand) -> (String, [String: HomeAssistantValue])? {
        switch command {
        case .toggle: return ("media_play_pause", [:])
        case .next: return ("media_next_track", [:])
        case .previous: return ("media_previous_track", [:])
        case .seek(let position): return ("media_seek", ["seek_position": .number(position.rounded())])
        default: return nil
        }
    }

    private func allows(_ command: NotchPlaybackCommand) -> Bool {
        guard connected, let player = active, !isPending(player.id),
              let (service, data) = Self.service(for: command) else { return false }
        return player.allows(service, data: data)
    }

    private func send(_ command: NotchPlaybackCommand) -> Bool {
        guard allows(command), let (service, data) = Self.service(for: command) else { return false }
        perform(service, data: data)
        return true
    }

    func loadFavorites(_ type: String) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let response = await self.home.musicAssistantFavorites(type) else { self.favoritesUnavailable = true; return }
            self.favoritesUnavailable = false
            self.favorites[type] = HomeAssistantLibraryItem.list(response, type: type)
        }
    }

    func play(_ item: HomeAssistantLibraryItem) {
        guard let id = active?.id else { return }
        home.playMusicAssistant(item, on: id)
    }

    /// Reads Music Assistant's current and next entry for the shown speaker.
    func loadQueue() {
        guard let id = active?.id else { return }
        queueTask?.cancel()
        queueLoading = true
        queueTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let response = await self.home.musicAssistantQueue(id)
            guard !Task.isCancelled, self.active?.id == id else { return }
            self.queueLoading = false
            self.upNext = response.map { HomeAssistantQueueItem.upNext($0, entityID: id) }
        }
    }

    private func loadArtwork(_ url: URL?) {
        guard url != artworkURL else { return }
        artworkURL = url
        artworkTask?.cancel()
        guard let url else { artwork = nil; artworkTint = nil; showOnIsland(); return }
        artworkTask = Task { @MainActor [weak self] in
            // ponytail: no cache, HA's proxy URL changes per track and the island shows one cover.
            let loaded = try? await URLSession.shared.data(from: url)
            guard !Task.isCancelled, let self, self.artworkURL == url else { return }
            guard let (data, response) = loaded, (response as? HTTPURLResponse)?.statusCode ?? 200 < 300,
                  let image = ImageThumbnailer.thumbnail(data: data, pointSize: 160, scale: 2) else {
                self.artwork = nil; self.artworkTint = nil; self.showOnIsland(); return
            }
            self.artwork = image
            self.artworkTint = NotchMusicService.artworkTint(of: image)
            self.showOnIsland()
        }
    }
}
