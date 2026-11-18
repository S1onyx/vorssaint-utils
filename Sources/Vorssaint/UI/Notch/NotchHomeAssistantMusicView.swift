// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The few words the Home Assistant player adds to the music page.
// ponytail: English and German only, others fall back to English; move into HomeAssistantStrings for all languages if upstreamed.
struct HomeAssistantMusicStrings {
    let group, leaveGroup, input, nothingPlaying, shuffle, repeatOff, repeatAll, repeatOne: String
    let queue, nowPlaying, upNext, noQueue, skip: String
    let library, playlists, albums, radio, tracks, artists, noLibrary, noFavorites, resume: String
    static func localized(_ language: AppLanguage) -> Self {
        language == .de
            ? Self(group: "Lautsprechergruppe", leaveGroup: "Gruppe auflösen", input: "Eingang",
                   nothingPlaying: "Keine Wiedergabe", shuffle: "Zufallswiedergabe", repeatOff: "Wiederholen: Aus",
                   repeatAll: "Wiederholen: Alle", repeatOne: "Wiederholen: Titel", queue: "Warteschlange",
                   nowPlaying: "Jetzt", upNext: "Als Nächstes",
                   noQueue: "Keine Warteschlange. Nur Music-Assistant-Player liefern eine.", skip: "Überspringen",
                   library: "Musik starten", playlists: "Playlists", albums: "Alben", radio: "Radio", tracks: "Titel",
                   artists: "Künstler", noLibrary: "Music Assistant ist in Home Assistant nicht eingerichtet.",
                   noFavorites: "Keine Favoriten. Markiere in Music Assistant etwas mit dem Stern.", resume: "Fortsetzen")
            : Self(group: "Speaker group", leaveGroup: "Ungroup", input: "Input", nothingPlaying: "Nothing playing",
                   shuffle: "Shuffle", repeatOff: "Repeat: Off", repeatAll: "Repeat: All", repeatOne: "Repeat: One",
                   queue: "Queue", nowPlaying: "Now", upNext: "Up next",
                   noQueue: "No queue. Only Music Assistant players provide one.", skip: "Skip",
                   library: "Start music", playlists: "Playlists", albums: "Albums", radio: "Radio", tracks: "Tracks",
                   artists: "Artists", noLibrary: "Music Assistant is not set up in Home Assistant.",
                   noFavorites: "No favorites. Star something in Music Assistant.", resume: "Resume")
    }
}

/// A Home Assistant media player in the island's player layout: cover and
/// song, the timeline, the transport between input and group, and its volume.
struct NotchHomeAssistantMusicView<Accessory: View, Corner: View>: View {
    let player: HomeAssistantMediaPlayer
    let width: CGFloat
    let bandHeight: CGFloat
    var showsCorner = false
    @ViewBuilder let accessory: () -> Accessory
    @ViewBuilder let corner: () -> Corner
    @ObservedObject private var music = HomeAssistantMusic.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchSettingsPreview) private var preview
    @State private var requestedPlaying: Bool?
    @State private var volumeDraft: Double?
    @State private var seekDraft: Double?
    @State private var showingQueue = false
    @State private var showingLibrary = false
    @AppStorage("notchHomeAssistantLibraryType") private var libraryType = "playlist"

    private var text: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }
    private var strings: HomeAssistantMusicStrings { .localized(l10n.language) }
    private var accent: Color { music.artworkTint?.color ?? .white }
    private var playing: Bool { requestedPlaying ?? player.isPlaying }
    private var pending: Bool { music.isPending(player.id) || !music.connected }

    var body: some View {
        VStack(spacing: 0) {
            head
            timeline
                .frame(height: NotchLayout.musicTimelineHeight)
                .padding(.top, NotchLayout.musicHeadSpacing)
            transport
                .frame(height: NotchLayout.musicTransportHeight)
                .padding(.top, NotchLayout.rowSpacing)
            volume
                .frame(height: NotchLayout.levelRowHeight)
                .padding(.top, NotchLayout.rowSpacing)
            Color.clear.frame(height: NotchLayout.musicBottomRoom)
        }
        .onChange(of: player.isPlaying) { if player.isPlaying == requestedPlaying { requestedPlaying = nil } }
        .onChange(of: player.title) { requestedPlaying = nil; seekDraft = nil }
        .task(id: requestedPlaying) {
            guard requestedPlaying != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { requestedPlaying = nil }
        }
    }

    // MARK: Head

    private var head: some View {
        HStack(alignment: .bottom, spacing: 14) {
            artwork
            VStack(alignment: .leading, spacing: 2) {
                Text(player.title ?? strings.nothingPlaying)
                    .font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    .help(player.title ?? player.name)
                Text(subtitle)
                    .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
                    .help(subtitle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: NotchLayout.musicTitleHeight)
            VStack(alignment: .trailing, spacing: 0) {
                if showsCorner { HStack(spacing: 6) { corner() }.frame(height: 28) }
                HStack(spacing: 8) {
                    libraryButton
                    queueButton
                    accessory()
                    NotchLiveEqualizerBars(isPlaying: player.isPlaying, bars: 4, barWidth: 2.5, height: 15,
                                           tint: .white.opacity(0.5))
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: NotchLayout.musicArtworkSize)
        }
        .frame(height: NotchLayout.musicHeadHeight(band: bandHeight), alignment: .bottom)
    }

    /// Artist, then where it plays: the speaker's name, with its group size.
    private var subtitle: String {
        let room = player.isGrouped ? "\(player.name) +\(player.groupMembers.filter { $0 != player.id }.count)" : player.name
        return [player.artist, room].compactMap { $0 }.joined(separator: " · ")
    }

    private var artwork: some View {
        Button {
            if let url = HomeAssistantService.shared.dashboardURL { NSWorkspace.shared.open(url) }
        } label: {
            NotchArtwork(image: music.artwork, size: NotchLayout.musicArtworkSize)
                .scaleEffect(player.isPlaying || reduceMotion ? 1 : 0.94)
                .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: player.isPlaying)
                // Says at a glance that this plays elsewhere, not on this Mac.
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color(red: 0.09, green: 0.66, blue: 0.95), in: Circle())
                        .overlay(Circle().stroke(.black, lineWidth: 2))
                        .offset(x: 4, y: 4)
                }
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: NotchLayout.musicArtworkSize * 0.19))
        .help("Home Assistant · \(player.name)")
        .accessibilityLabel("Home Assistant · \(player.name)")
    }

    // MARK: Timeline

    @ViewBuilder private var timeline: some View {
        if player.duration > 0 {
            TimelineView(.animation(minimumInterval: 1, paused: !player.isPlaying)) { context in
                let position = seekDraft ?? player.position(at: context.date)
                HStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        Text(Self.timestamp(player.duration)).hidden()
                        Text(Self.timestamp(position))
                    }
                    if player.supports(.seek) {
                        NotchLevelSlider(
                            value: Binding(get: { position }, set: { seekDraft = $0 }),
                            label: FeatureStrings.notch(l10n.language).playbackPosition,
                            range: 0...player.duration, tint: accent, valueLabel: Self.timestamp(position),
                            scrollable: false,
                            onEditingChanged: { editing in
                                guard !editing, let seekDraft else { return }
                                music.perform("media_seek", data: ["seek_position": .number(seekDraft.rounded())])
                            })
                            .frame(height: 10)
                            .disabled(pending)
                    } else {
                        NotchMeter(value: position / player.duration, height: 6, tint: accent)
                    }
                    ZStack(alignment: .trailing) {
                        Text("−" + Self.timestamp(player.duration)).hidden()
                        Text("−" + Self.timestamp(player.duration - position))
                    }
                }
                .font(.system(size: 10, weight: .medium)).monospacedDigit().foregroundStyle(.secondary)
            }
            // The server's next position report replaces the dragged one.
            .onChange(of: player.entity.attributes["media_position_updated_at"]) { seekDraft = nil }
        } else {
            NotchMeter(value: 0, height: 6, tint: accent).opacity(0.4)
        }
    }

    static func timestamp(_ interval: TimeInterval) -> String {
        let seconds = Int(min(604_800, max(0, interval)))
        return seconds >= 3600
            ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
            : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: Transport

    /// Five equal places as on this Mac's player: shuffle, the transport, repeat.
    private var transport: some View {
        let slot = width / 5
        return HStack(spacing: 0) {
            Color.clear.frame(width: slot).overlay { shuffleButton }
            transportButton("backward.fill", title: text.mediaPrevious, size: 19, service: "media_previous_track",
                            offered: player.supports(.previous)).frame(width: slot)
            Button {
                requestedPlaying = !playing
                // Nothing loaded: pick up where the speaker's queue left off.
                music.perform(player.hasMedia ? "media_play_pause" : "media_play")
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: playing)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(NotchButtonStyle(cornerRadius: 22))
            .disabled(pending || !(player.supports(.pause) || player.supports(.play)))
            .help(player.hasMedia ? text.mediaPlayPause : strings.resume)
            .keyboardShortcut(preview ? nil : KeyboardShortcut(.space, modifiers: []))
            .accessibilityLabel(player.hasMedia ? text.mediaPlayPause : strings.resume)
            .frame(width: slot)
            transportButton("forward.fill", title: text.mediaNext, size: 19, service: "media_next_track",
                            offered: player.supports(.next)).frame(width: slot)
            Color.clear.frame(width: slot).overlay { repeatButton }
        }
    }

    @ViewBuilder private var shuffleButton: some View {
        if player.supports(.shuffle) {
            Button { music.perform("shuffle_set", data: ["shuffle": .bool(!player.shuffle)]) } label: {
                sideGlyph("shuffle", active: player.shuffle)
            }
            .buttonStyle(NotchButtonStyle(cornerRadius: 22))
            .disabled(pending)
            .help(strings.shuffle)
            .accessibilityLabel(strings.shuffle)
            .accessibilityAddTraits(player.shuffle ? .isSelected : [])
        }
    }

    /// Steps off, all, one, as phones do.
    @ViewBuilder private var repeatButton: some View {
        if player.supports(.repeatMode) {
            let title = player.repeatMode == "one" ? strings.repeatOne
                : player.repeatMode == "all" ? strings.repeatAll : strings.repeatOff
            Button { music.perform("repeat_set", data: ["repeat": .string(player.nextRepeatMode)]) } label: {
                sideGlyph(player.repeatMode == "one" ? "repeat.1" : "repeat", active: player.repeatMode != "off")
            }
            .buttonStyle(NotchButtonStyle(cornerRadius: 22))
            .disabled(pending)
            .help(title)
            .accessibilityLabel(title)
        }
    }

    // MARK: Library

    private var libraryTypes: [(String, String)] {
        [("playlist", strings.playlists), ("album", strings.albums), ("radio", strings.radio),
         ("track", strings.tracks), ("artist", strings.artists)]
    }

    /// Music Assistant favorites, played on this speaker with a click.
    private var libraryButton: some View {
        NotchIconButton(symbol: "music.note.house", title: strings.library, selected: showingLibrary) {
            showingLibrary.toggle()
            if showingLibrary { music.loadFavorites(libraryType) }
        }
        .disabled(!music.connected)
        .popover(isPresented: $showingLibrary, arrowEdge: .bottom) { libraryPanel }
    }

    private var libraryPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(strings.library, selection: $libraryType) {
                ForEach(libraryTypes, id: \.0) { Text($0.1).tag($0.0) }
            }
            .pickerStyle(.segmented).labelsHidden()
            .onChange(of: libraryType) { music.loadFavorites(libraryType) }
            if music.favoritesUnavailable {
                Text(strings.noLibrary).font(.caption).foregroundStyle(.secondary)
            } else if let items = music.favorites[libraryType] {
                if items.isEmpty {
                    Text(strings.noFavorites).font(.caption).foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(items) { item in
                                Button { music.play(item); showingLibrary = false } label: { libraryRow(item) }
                                    .buttonStyle(NotchButtonStyle(cornerRadius: 8))
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            } else {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .frame(width: 340)
    }

    private func libraryRow(_ item: HomeAssistantLibraryItem) -> some View {
        HStack(spacing: 10) {
            cover(item.imageURL, size: 34, round: item.type == "artist")
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                if let artist = item.artist {
                    Text(artist).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "play.fill").font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func cover(_ url: URL?, size: CGFloat, round: Bool = false) -> some View {
        AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: {
            Image(systemName: "music.note").foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(.quaternary)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: round ? size / 2 : 7, style: .continuous))
    }

    // MARK: Queue

    /// Music Assistant's current and next entry. Home Assistant returns no more.
    private var queueButton: some View {
        NotchIconButton(symbol: "list.bullet", title: strings.queue, selected: showingQueue) {
            showingQueue.toggle()
            if showingQueue { music.loadQueue() }
        }
        .disabled(!music.connected)
        .popover(isPresented: $showingQueue, arrowEdge: .bottom) { queuePanel }
        .onChange(of: player.title) { if showingQueue { music.loadQueue() } }
    }

    private var queuePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let upNext = music.upNext, upNext.current != nil || upNext.next != nil {
                if let current = upNext.current { queueRow(strings.nowPlaying, current) }
                if let next = upNext.next {
                    queueRow(strings.upNext, next)
                    Button(strings.skip) { music.perform("media_next_track") }
                        .disabled(pending || !player.supports(.next))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else if music.queueLoading {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity)
            } else {
                Text(strings.noQueue).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(width: 260)
    }

    private func queueRow(_ label: String, _ item: HomeAssistantQueueItem) -> some View {
        HStack(spacing: 10) {
            cover(item.imageURL, size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                Text(item.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                if let artist = item.artist {
                    Text(artist).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if item.duration > 0 {
                Text(Self.timestamp(item.duration)).font(.system(size: 10)).monospacedDigit().foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func transportButton(_ symbol: String, title: String, size: CGFloat, service: String,
                                              offered: Bool) -> some View {
        if offered {
            Button { music.perform(service) } label: {
                Image(systemName: symbol)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(NotchButtonStyle(cornerRadius: 22))
            .disabled(pending)
            .accessibilityLabel(title)
            .help(title)
        }
    }

    private func sideGlyph(_ symbol: String, active: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(active ? accent : .white.opacity(0.55))
            .frame(width: 32, height: 32)
            .background(.white.opacity(active ? 0.12 : 0), in: Circle())
            .frame(width: 44, height: 44)
            .contentShape(Circle())
    }

    private func rowGlyph(_ symbol: String, active: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(active ? accent : .white.opacity(0.7))
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
    }

    /// The player's own inputs, such as a speaker's line-in or a Music Assistant queue.
    @ViewBuilder private var inputMenu: some View {
        if player.supports(.selectSource), !player.sources.isEmpty {
            let items = player.sources.map { source in
                NotchMenuItem(title: source, checked: source == player.source) {
                    music.perform("select_source", data: ["source": .string(source)])
                }
            }
            NotchMenuButton(title: strings.input, items: items, cornerRadius: 6) {
                rowGlyph("square.stack.3d.down.right", active: false)
            }
            .disabled(pending)
            .help([strings.input, player.source].compactMap { $0 }.joined(separator: ": "))
        }
    }

    /// Speakers that can join this one. A checked speaker plays the same music;
    /// choosing it again takes it back out of the group.
    @ViewBuilder private var groupMenu: some View {
        if player.supports(.grouping) {
            let members = Set(player.groupMembers)
            let others = music.players.filter { $0.id != player.id && $0.supports(.grouping) }
            let items = others.map { other in
                NotchMenuItem(title: other.name, checked: members.contains(other.id)) {
                    if members.contains(other.id) { music.perform("unjoin", on: other.id) }
                    else { music.perform("join", data: ["group_members": .array([.string(other.id)])]) }
                }
            } + (player.isGrouped ? [.separator, NotchMenuItem(title: strings.leaveGroup, symbol: "rectangle.badge.minus") {
                music.perform("unjoin")
            }] : [])
            NotchMenuButton(title: strings.group, items: items, cornerRadius: 6) {
                rowGlyph(player.isGrouped ? "hifispeaker.2.fill" : "hifispeaker.2", active: player.isGrouped)
            }
            .disabled(pending || items.isEmpty)
            .help(strings.group)
        }
    }

    // MARK: Volume

    @ViewBuilder private var volume: some View {
        HStack(spacing: 6) {
            Button {
                music.perform("volume_mute", data: ["is_volume_muted": .bool(!player.muted)])
            } label: {
                Image(systemName: player.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(player.muted ? Color.red : Color.white)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(NotchButtonStyle(cornerRadius: 6))
            .disabled(pending || !player.supports(.volumeMute))
            .accessibilityLabel(player.muted ? l10n.s.actionUnmute : l10n.s.actionMute)
            if let level = volumeDraft ?? player.volume, player.supports(.volumeSet) {
                NotchLevelSlider(value: Binding(get: { player.muted && volumeDraft == nil ? 0 : level },
                                                set: { volumeDraft = $0 }),
                                 label: FeatureStrings.notch(l10n.language).volume, tint: accent,
                                 trackThickness: 8, easesChanges: true, scrollable: false,
                                 onEditingChanged: { editing in
                                     guard !editing, let volumeDraft else { return }
                                     music.perform("volume_set", data: ["volume_level": .number((volumeDraft * 100).rounded() / 100)])
                                 })
                    .frame(height: 24)
                    .disabled(pending)
                Text("\(Int((level * 100).rounded()))%")
                    .font(.system(size: 10, weight: .medium)).monospacedDigit().foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .trailing)
            } else {
                Spacer(minLength: 0)
            }
            // The speaker's choosers end its row, as the output does on this Mac's.
            inputMenu
            groupMenu
        }
        // The server's confirmed level replaces the dragged one.
        .onChange(of: player.volume) { volumeDraft = nil }
    }
}
