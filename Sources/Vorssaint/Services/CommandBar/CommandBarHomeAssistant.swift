// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

extension CommandBarCatalog {
    /// Home Assistant scenes, scripts, lights, switches and covers as rows.
    /// A number sets a light's brightness or a cover's position ("Kitchen 40").
    /// Each row takes a shortcut of its own like any other row.
    /// Locks and alarms stay out: they ask before acting, which the bar cannot.
    static func homeAssistantEntries() -> [CommandBarEntry] {
        let service = HomeAssistantService.shared
        guard service.enabled, service.connection == .connected,
              UserDefaults.standard.object(forKey: DefaultsKey.notchHomeAssistantCommandBar) as? Bool ?? true else { return [] }
        return service.entities.values
            .filter { ["scene", "script", "light", "switch", "cover"].contains($0.domain) && $0.eligible }
            .map { entity in
                let id = entity.id
                let numeric = entity.hasBrightness || entity.hasPosition
                return CommandBarEntry(
                    id: "home-assistant.\(id)",
                    title: service.displayName(id),
                    subtitle: "Home Assistant",
                    keywords: id + " home assistant " + entity.domain,
                    icon: .symbol(entity.symbol),
                    isActive: entity.state == "on" || entity.state == "open",
                    numericRange: numeric ? 0...100 : nil,
                    numericIsOptional: true,
                    run: { number in
                        let service = HomeAssistantService.shared
                        if let number, numeric { service.setBrightness(Double(number), entityID: id); return }
                        guard let current = service.entities[id], let action = current.primaryService else { return }
                        service.perform(action, entityID: id)
                    })
            }
    }
}
