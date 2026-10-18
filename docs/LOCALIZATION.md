# Localization

Concise reference to the implementation in `Localization.lua`, `StorageManager.lua`, and `lib/i18n/`.

- Supported locales: `en`, `pt-BR`, and `es`; display names are English, Português (Brasil), and Español.
- `Localization.text(sourceEnglish, ...)` uses the English source string as the msgid, looks it up in the locale catalog, and falls back to English when missing. Preserve `string.format` placeholder compatibility.
- `Localization.label` translates visible text while preserving the ImGui ID: text before `###` or `##` is displayed; the suffix after the marker is a hidden ID and must not be translated. A hidden-only label beginning with `##` remains unchanged.
- The global storage field `uiLanguage` defaults to `en`. An invalid persisted locale falls back to English without rewriting the stored value; `setLocale` rejects invalid values without changing the locale.
- Translate UI presentation, not numeric enums, keys, track/car data, logs, or simulation reason strings.
- `behavior.profile` is not declared in the storage schema. The UI infers a profile by comparing only some persisted values, so the inference is partial and must not be described as reliable for every combination. `advancedBehaviorOpen` is local UI state, not persisted.
- Translation changes require msgid/placeholder parity and stable IDs. See [`tools/test_localization.lua`](../tools/test_localization.lua) and the command in [Testing](TESTING.md).
