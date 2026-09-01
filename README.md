# Word of the Day — SwiftUI foundation

This repository contains source files for an iOS app and Lock Screen widget.

## Included features

- Daily word with definition, example, phonetic spelling, and speech playback
- SwiftData vocabulary history with bookmark filtering
- Opt-in daily local notification at 9:00 AM
- Inline, rectangular, and circular Lock Screen widgets
- Small and medium Home Screen widgets
- Shared App Group cache and midnight widget timeline refresh

## Open and run in Xcode

1. Open `WordOfTheDay.xcodeproj` and select the `WordOfTheDay` scheme.
2. Select the `WordOfTheDay` app target, open **Signing & Capabilities**, choose
   your Apple Developer team, and replace `com.yourapp.wordoftheday` with a
   bundle identifier you own.
3. Repeat for `WordOfTheDayWidgetExtension`, using an identifier below the app's
   identifier, such as `your.app.identifier.widget`.
4. Under the App Groups capability for both targets, replace
   `group.com.yourapp.wordoftheday` with an App Group owned by your team. Make
   the same replacement in `Shared/WordStorage.swift` and both `.entitlements`
   files.
5. Select an iPhone Simulator and press **Run**. The widget extension is already
   embedded in the app target.

Set `WORD_API_ENDPOINT` and, if required, `WORD_API_KEY` in
`WordOfTheDayApp/Info.plist`. The endpoint is expected to return:

```json
{
  "id": "A96FEF10-3F47-4C27-9830-36DAA00484C6",
  "word": "Ephemeral",
  "phonetic": "/ɪˈfem.ər.əl/",
  "partOfSpeech": "adjective",
  "definition": "Lasting for only a short time.",
  "exampleSentence": "The ephemeral glow faded.",
  "synonyms": ["fleeting", "transient", "momentary"],
  "antonyms": ["permanent", "enduring", "lasting"],
  "date": "2026-08-31T12:00:00Z"
}
```

`id`, `date`, `synonyms`, and `antonyms` are optional. With no endpoint, invalid configuration, or a
failed request, the service returns the built-in fallback entry.

The project deployment target is iOS 17 because vocabulary history uses
SwiftData.
