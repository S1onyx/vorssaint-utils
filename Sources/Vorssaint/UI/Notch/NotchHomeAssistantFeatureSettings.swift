// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Settings for this fork's Home Assistant additions. Cards carry their
/// heading inside, not as a `title:`, since Settings search does not index them.
struct HomeAssistantFeatureSettings: View {
    @ObservedObject private var service = HomeAssistantService.shared
    @ObservedObject private var l10n = L10n.shared
    private var text: HomeAssistantExtraStrings { .localized(l10n.language) }

    var body: some View {
        SettingsCard {
            heading(text["doorbell"], "bell.fill")
            Text(text["doorbellHint"]).font(.caption).foregroundStyle(.secondary)
            picker(text["trigger"], key: DefaultsKey.notchHomeAssistantDoorbell, current: service.doorbellID) {
                ["binary_sensor", "event"].contains($0.domain)
            }
            picker(text["camera"], key: DefaultsKey.notchHomeAssistantDoorbellCamera, current: service.doorbellCameraID) {
                $0.domain == "camera"
            }
            picker(text["lock"], key: DefaultsKey.notchHomeAssistantDoorbellLock, current: service.doorbellLockID) {
                $0.domain == "lock"
            }
        }
        SettingsCard {
            heading(text["notifications"], "bell.badge")
            Text(text["notificationsHint"]).font(.caption).foregroundStyle(.secondary)
            Toggle(isOn: Binding(get: { service.showsNotifications }, set: { service.setShowsNotifications($0) })) {
                Text(text["showNotifications"])
            }
        }
        SettingsCard {
            heading(text["strip"], "thermometer.sun")
            Text(text["stripHint"]).font(.caption).foregroundStyle(.secondary)
            ForEach(0..<3, id: \.self) { index in glancePicker(index) }
            Divider()
            Toggle(isOn: $presence) { Text(text["presence"]) }
            Text(text["presenceHint"]).font(.caption).foregroundStyle(.secondary)
            Toggle(isOn: $commandBar) { Text(text["scenes"]) }
            Text(text["scenesHint"]).font(.caption).foregroundStyle(.secondary)
        }
    }

    @AppStorage(DefaultsKey.notchHomeAssistantPresence) private var presence = true
    @AppStorage(DefaultsKey.notchHomeAssistantCommandBar) private var commandBar = true

    private func glancePicker(_ index: Int) -> some View {
        let ids = HomeAssistantGlance.ids()
        let current = index < ids.count ? ids[index] : ""
        let options = service.entities.values.filter(HomeAssistantGlance.accepts)
            .sorted { service.displayName($0.id).localizedStandardCompare(service.displayName($1.id)) == .orderedAscending }
        return Picker(selection: Binding(get: { current }, set: { HomeAssistantGlance.set($0, at: index); service.objectWillChange.send() })) {
            Text(text["none"]).tag("")
            if !current.isEmpty, !options.contains(where: { $0.id == current }) { Text(current).tag(current) }
            ForEach(options) { Text(service.displayName($0.id)).tag($0.id) }
        } label: { Text("\(index + 1).") }
    }

    func heading(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.headline)
    }

    /// Entities of the kinds `matches` accepts, by name; a saved choice stays listed while offline.
    func picker(_ label: String, key: String, current: String,
                matches: (HomeAssistantEntity) -> Bool) -> some View {
        let options = service.entities.values.filter(matches)
            .sorted { service.displayName($0.id).localizedStandardCompare(service.displayName($1.id)) == .orderedAscending }
        return Picker(selection: Binding(get: { current }, set: { service.setDoorbell($0, key: key) })) {
            Text(text["none"]).tag("")
            if !current.isEmpty, !options.contains(where: { $0.id == current }) { Text(current).tag(current) }
            ForEach(options) { Text(service.displayName($0.id)).tag($0.id) }
        } label: { Text(label) }
    }
}

/// Extras in the island's Home Assistant header: notifications, and who is home.
struct HomeAssistantHeaderExtras: View {
    @ObservedObject private var service = HomeAssistantService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchHomeAssistantPresence) private var presence = true
    @State private var showing = false
    private var text: HomeAssistantExtraStrings { .localized(l10n.language) }

    var body: some View {
        HStack(spacing: 10) {
            glance
            if presence { people }
            bell
        }
    }

    /// The chosen readings: weather with its sky, a climate device's or a sensor's value.
    private var glance: some View {
        HStack(spacing: 8) {
            ForEach(HomeAssistantGlance.ids(), id: \.self) { id in
                if let entity = service.entities[id] {
                    let item = HomeAssistantGlance.reading(entity, temperatureUnit: service.temperatureUnit)
                    Label(item.value, systemImage: item.symbol)
                        .font(.system(size: 11, weight: .medium)).monospacedDigit().lineLimit(1)
                        .symbolRenderingMode(.multicolor)
                        .help(service.displayName(id) + ": " + item.value)
                }
            }
        }
    }

    /// Who is home, as initials: filled at home, outlined away.
    private var people: some View {
        let persons = service.entities.values.filter { $0.domain == "person" }.sorted { $0.name < $1.name }
        return HStack(spacing: -4) {
            ForEach(persons) { person in personBadge(person) }
        }
    }

    private func personBadge(_ person: HomeAssistantEntity) -> some View {
        let home = person.state == "home"
        let where_: String = home ? text["home"] : (text.state(person.state) ?? person.state)
        let fill: Color = home ? .green : .white.opacity(0.08)
        let ink: Color = home ? .black : .secondary
        return Text(String(person.name.prefix(1)).uppercased())
            .font(.system(size: 9, weight: .bold))
            .frame(width: 18, height: 18)
            .foregroundStyle(ink)
            .background(fill, in: Circle())
            .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
            .help(person.name + ": " + where_)
            .accessibilityLabel(person.name + ", " + (home ? text["home"] : text["away"]))
    }

    @ViewBuilder private var bell: some View {
        if !service.notifications.isEmpty {
            Button { showing.toggle() } label: {
                Image(systemName: "bell.badge.fill").symbolRenderingMode(.multicolor)
                    .overlay(alignment: .topTrailing) {
                        Text("\(service.notifications.count)").font(.system(size: 8, weight: .bold)).monospacedDigit()
                            .padding(.horizontal, 3).background(.red, in: Capsule()).offset(x: 7, y: -6)
                    }
            }
            .help(text["notifications"]).accessibilityLabel(text["notifications"])
            .accessibilityValue("\(service.notifications.count)")
            .popover(isPresented: $showing, arrowEdge: .bottom) { list }
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(service.notifications) { item in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            if !item.title.isEmpty { Text(item.title).font(.system(size: 12, weight: .semibold)) }
                            Text(item.message).font(.system(size: 11)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(item.created, style: .relative).font(.system(size: 9)).foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 0)
                        Button { service.dismissNotification(item.id) } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                            .help(text["dismiss"]).accessibilityLabel(text["dismiss"])
                    }
                    Divider()
                }
            }
            .padding(12)
        }
        .frame(width: 300).frame(maxHeight: 340)
    }
}

