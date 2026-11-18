// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// A camera's picture from Home Assistant's proxy, fetched again every
/// `interval` seconds while it is on screen. One second reads as live.
// ponytail: snapshots, not the MJPEG stream; a stream reader if a second is too slow.
struct HomeAssistantCameraImage: View {
    let entityID: String
    var interval: TimeInterval = 10
    var fit = false
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: fit ? .fit : .fill)
            } else {
                Color.black.overlay { ProgressView().controlSize(.small) }
            }
        }
        .task(id: entityID) {
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    @MainActor private func load() async {
        let service = HomeAssistantService.shared
        guard service.connection == .connected,
              let url = service.entities[entityID]?.pictureURL(base: service.dashboardURL) else { return }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode ?? 200 < 300,
              let next = ImageThumbnailer.thumbnail(data: data, pointSize: 640, scale: 2) else { return }
        image = next
    }
}

/// Runs an action, asking first where it opens a door or disarms an alarm,
/// and for the code when the device wants one. The code is sent once and never kept.
enum HomeAssistantConfirmation {
    static func perform(_ service: String, entity: HomeAssistantEntity, name: String) {
        let confirm = HomeAssistantAction.needsConfirmation(service)
        // Alarms ask for their code to arm and disarm; locks name one for every action.
        let code = entity.needsCode
        var data: [String: HomeAssistantValue] = [:]
        if confirm || code {
            let text = HomeAssistantExtraStrings.current
            let alert = NSAlert()
            let key = service == "unlock" ? "confirmUnlock" : service == "open" ? "confirmOpen"
                : service == "alarm_disarm" ? "confirmDisarm" : nil
            alert.messageText = key.map { String(format: text[$0], name) } ?? name
            alert.addButton(withTitle: text["confirm"])
            alert.addButton(withTitle: text["cancel"])
            let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
            field.placeholderString = text["code"]
            if code { alert.accessoryView = field; alert.window.initialFirstResponder = field }
            guard NotchIslandAlert.run(alert, above: NotchService.shared.presentationWindow) == .alertFirstButtonReturn else { return }
            if code {
                guard !field.stringValue.isEmpty else { return }
                data["code"] = .string(field.stringValue)
            }
        }
        HomeAssistantService.shared.perform(service, entityID: entity.id, data: data)
    }
}

/// Lock and alarm buttons for an entity's details.
struct HomeAssistantSecurityControls: View {
    let entity: HomeAssistantEntity
    let name: String
    private var text: HomeAssistantExtraStrings { .current }

    var body: some View {
        HStack {
            switch entity.domain {
            case "lock":
                button("lockAction", "lock", "lock.fill")
                button("unlockDoor", "unlock", "lock.open.fill")
                if entity.supports(1) { button("openDoor", "open", "door.left.hand.open") }
            case "alarm_control_panel":
                if entity.supports(1) { button("armHome", "alarm_arm_home", "house.fill") }
                if entity.supports(2) { button("armAway", "alarm_arm_away", "figure.walk") }
                if entity.supports(4) { button("armNight", "alarm_arm_night", "moon.fill") }
                button("disarm", "alarm_disarm", "shield.slash")
            default: EmptyView()
            }
        }
        .buttonStyle(.bordered)
    }

    private func button(_ title: String, _ service: String, _ symbol: String) -> some View {
        Button { HomeAssistantConfirmation.perform(service, entity: entity, name: name) } label: {
            Label(text[title], systemImage: symbol)
        }
    }
}
