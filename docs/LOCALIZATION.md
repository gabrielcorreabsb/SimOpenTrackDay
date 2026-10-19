# Localization

Concise reference to the implementation in `Localization.lua`, `StorageManager.lua`, `UIStorage.lua`, and `lib/i18n/`.

- Supported locales: `en`, `pt-BR`, and `es`; display names are English, Português (Brasil), and Español.
- `Localization.text(sourceEnglish, ...)` uses the English source string as the msgid, looks it up in the locale catalog, and falls back to English when missing. Preserve `string.format` placeholder compatibility.
- `Localization.label` translates visible text while preserving the ImGui ID: text before `###` or `##` is displayed; the suffix after the marker is a hidden ID and must not be translated. A hidden-only label beginning with `##` remains unchanged.
- Language preferences use `StorageManager.getStorage_UI()` and its declared `uiLanguage` field in the app-wide `ui` namespace, independent of track and session mode. An empty string marks first use: a valid legacy `global.uiLanguage` is migrated without rewriting the legacy value; a missing legacy key or invalid value defaults to English. A valid UI preference takes precedence. Invalid persisted UI values fall back to English without being rewritten, and `setLocale` rejects invalid values. Valid selections persist in UI storage; storage failures propagate instead of silently using session-only preferences.
- `UIStorage.lua` owns the shared schema and lazily creates one storage handle. The manager getter delegates to it; if a legacy manager lacks `getStorage_UI`, `Localization` uses the same shared storage directly. A present but invalid or failing getter remains an error. Include `UIStorage.lua` in the root runtime payload.
- Translate UI presentation, not numeric enums, keys, track/car data, logs, or simulation reason strings.
- `behavior.profile` is not declared in the storage schema. The UI infers a profile by comparing only some persisted values, so the inference is partial and must not be described as reliable for every combination. `advancedBehaviorOpen` is local UI state, not persisted.
- Translation changes require msgid/placeholder parity and stable IDs. See [`tools/test_localization.lua`](../tools/test_localization.lua) and the command in [Testing](TESTING.md).
