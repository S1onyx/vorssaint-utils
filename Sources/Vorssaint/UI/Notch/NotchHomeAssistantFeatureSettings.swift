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
