// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Words for this fork's Home Assistant additions: cameras, the doorbell,
/// locks, alarms, notifications, the compact strip and presence.
// ponytail: English and German only, others fall back to English; move into HomeAssistantStrings for all languages if upstreamed.
struct HomeAssistantExtraStrings {
    private let values: [String: String]
    private let german: Bool
    subscript(_ key: String) -> String { values[key] ?? key }

    static func localized(_ language: AppLanguage) -> Self {
        let german = language == .de
        return Self(values: german ? Self.de : Self.en, german: german)
    }
    static var current: Self { localized(L10n.shared.language) }

    /// Device states the original strings leave as raw identifiers.
    func state(_ state: String) -> String? { values["state." + state] }

    private static let en: [String: String] = [
        "doorbell": "Doorbell", "doorbellHint": "When the doorbell rings, the island opens with the camera.",
        "trigger": "Ring sensor or event", "camera": "Camera", "lock": "Door lock", "none": "None",
        "ringing": "Someone is at the door", "openDoor": "Open door", "unlockDoor": "Unlock",
        "confirmUnlock": "Unlock %@?", "confirmOpen": "Open %@?", "confirmDisarm": "Disarm %@?",
        "confirm": "Confirm", "cancel": "Cancel", "code": "Code",
        "lockAction": "Lock", "armHome": "Arm home", "armAway": "Arm away", "armNight": "Arm night", "disarm": "Disarm",
        "notifications": "Notifications", "notificationsHint": "Show Home Assistant’s persistent notifications in the island.",
        "showNotifications": "Show notifications", "dismiss": "Dismiss",
        "strip": "Compact strip", "stripHint": "Show up to three readings, such as weather or room temperature, beside the camera while nothing else is shown.",
        "weather": "Weather", "presence": "People at home", "presenceHint": "Show who is home in the island’s Home Assistant header.",
        "scenes": "Shortcuts", "scenesHint": "Run scenes and scripts from the command bar.",
        "home": "Home", "away": "Away",
        "state.locked": "Locked", "state.unlocked": "Unlocked", "state.locking": "Locking", "state.unlocking": "Unlocking",
        "state.jammed": "Jammed", "state.open": "Open", "state.opening": "Opening", "state.closed": "Closed",
        "state.closing": "Closing", "state.armed_home": "Armed home", "state.armed_away": "Armed away",
        "state.armed_night": "Armed night", "state.armed_vacation": "Armed vacation", "state.disarmed": "Disarmed",
        "state.arming": "Arming", "state.pending": "Pending", "state.triggered": "Triggered", "state.idle": "Idle",
        "state.recording": "Recording", "state.streaming": "Live", "state.home": "Home", "state.not_home": "Away",
        "state.sunny": "Sunny", "state.clear-night": "Clear", "state.partlycloudy": "Partly cloudy", "state.cloudy": "Cloudy",
        "state.rainy": "Rain", "state.pouring": "Heavy rain", "state.snowy": "Snow", "state.fog": "Fog",
        "state.lightning": "Thunder", "state.lightning-rainy": "Thunderstorm", "state.windy": "Windy",
        "state.snowy-rainy": "Sleet", "state.hail": "Hail", "state.exceptional": "Severe",
    ]
    private static let de: [String: String] = [
        "doorbell": "Türklingel", "doorbellHint": "Klingelt es, öffnet sich die Island mit dem Kamerabild.",
        "trigger": "Klingel-Sensor oder -Ereignis", "camera": "Kamera", "lock": "Türschloss", "none": "Keine",
        "ringing": "Es klingelt", "openDoor": "Tür öffnen", "unlockDoor": "Aufschließen",
        "confirmUnlock": "%@ aufschließen?", "confirmOpen": "%@ öffnen?", "confirmDisarm": "%@ unscharf schalten?",
        "confirm": "Bestätigen", "cancel": "Abbrechen", "code": "Code",
        "lockAction": "Abschließen", "armHome": "Scharf (zuhause)", "armAway": "Scharf (abwesend)",
        "armNight": "Scharf (Nacht)", "disarm": "Unscharf",
        "notifications": "Benachrichtigungen", "notificationsHint": "Dauerhafte Benachrichtigungen aus Home Assistant in der Island zeigen.",
        "showNotifications": "Benachrichtigungen zeigen", "dismiss": "Verwerfen",
        "strip": "Kompakt-Leiste", "stripHint": "Bis zu drei Werte, etwa Wetter oder Raumtemperatur, neben der Kamera zeigen, solange sonst nichts angezeigt wird.",
        "weather": "Wetter", "presence": "Personen zuhause", "presenceHint": "Zeigt in der Home-Assistant-Kopfzeile der Island, wer zuhause ist.",
        "scenes": "Kurzbefehle", "scenesHint": "Szenen und Skripte aus der Befehlsleiste starten.",
        "home": "Zuhause", "away": "Unterwegs",
        "state.locked": "Verriegelt", "state.unlocked": "Entriegelt", "state.locking": "Verriegelt …", "state.unlocking": "Entriegelt …",
        "state.jammed": "Blockiert", "state.open": "Offen", "state.opening": "Öffnet", "state.closed": "Geschlossen",
        "state.closing": "Schließt", "state.armed_home": "Scharf (zuhause)", "state.armed_away": "Scharf (abwesend)",
        "state.armed_night": "Scharf (Nacht)", "state.armed_vacation": "Scharf (Urlaub)", "state.disarmed": "Unscharf",
        "state.arming": "Wird scharf", "state.pending": "Verzögerung", "state.triggered": "Ausgelöst", "state.idle": "Bereit",
        "state.recording": "Aufnahme", "state.streaming": "Live", "state.home": "Zuhause", "state.not_home": "Unterwegs",
        "state.sunny": "Sonnig", "state.clear-night": "Klar", "state.partlycloudy": "Teils bewölkt", "state.cloudy": "Bewölkt",
        "state.rainy": "Regen", "state.pouring": "Starkregen", "state.snowy": "Schnee", "state.fog": "Nebel",
        "state.lightning": "Gewitter", "state.lightning-rainy": "Gewitterregen", "state.windy": "Windig",
        "state.snowy-rainy": "Schneeregen", "state.hail": "Hagel", "state.exceptional": "Unwetter",
    ]
}
