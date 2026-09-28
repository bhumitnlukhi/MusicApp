# Pulse — Flutter Music App

A music streaming app built with Flutter, with a bold editorial design: ink-black and warm off-white screens, condensed headlines and a single neon accent. The accent **changes with every song**, using a color taken from the album art.

> ⚠️ **Learning project only.** Music comes from JioSaavn's **unofficial** API (via the [`jiosaavn`](https://pub.dev/packages/jiosaavn) package). Those songs are copyrighted, and using these endpoints goes against JioSaavn's Terms of Service. Don't publish this app to the Play Store / App Store, and don't monetize it. See [Switching the music source](#switching-the-music-source) for legal alternatives.

---

## Features

- **Discover**: hero mix, recently played, your mixes, popular artists, and filter chips (For You, Mood, New Releases, Charts)
- **Search**: live search across songs, artists and albums, plus Trending Now and Browse by Genre
- **Library**: create, rename and delete playlists; Liked Songs; followed artists; saved albums
- **Artist page**: photo header, follower count, Follow button, popular songs, albums, About tab
- **Album / playlist pages**: play, shuffle, save album, remove from playlist
- **Now Playing**: large artwork, waveform scrubber, shuffle, repeat (all / one), like
- **Synced lyrics**: the current line is highlighted and auto-scrolls; tap a line to jump to it
- **Queue**: drag to reorder, swipe to remove, clear, shuffle, repeat
- **Mini player** on every screen
- **Background playback** with lock-screen / notification controls (Android and iOS)
- **Per-song color theme**: the accent and background colors are taken from each song's album art and fade in smoothly
- Library data is **saved on the device** (liked songs, playlists, followed artists, saved albums, recently played)

## Screens

| Screen | Theme |
|---|---|
| Onboarding | Light |
| Discover (Home) | Dark |
| Search | Light |
| Your Library | Dark |
| Playlist / Album / Liked Songs | Light |
| Artist | Dark |
| Now Playing | Dark, tinted with the song's color |
| Lyrics | Light |
| Queue | Dark, tinted with the song's color |

---

## Getting started

### Requirements
- **Flutter 3.47.5** (stable, Dart 3.13.4). The version is pinned with [FVM](https://fvm.app) in [`.fvmrc`](.fvmrc).
- For iOS: Xcode with an iOS Simulator or a device
- For Android: Android Studio with an emulator or a device

### Flutter version (FVM)
This project uses **FVM (Flutter Version Management)**, so everyone builds with the same Flutter version no matter what's installed globally.

```bash
# 1. Install FVM (once per machine)
brew tap leoafarias/fvm && brew install fvm   # macOS
# or: dart pub global activate fvm

# 2. Inside the project: install the pinned Flutter version from .fvmrc
fvm install
```

Then put `fvm` in front of every Flutter command:

| Instead of | Use |
|---|---|
| `flutter pub get` | `fvm flutter pub get` |
| `flutter run` | `fvm flutter run` |
| `dart format lib` | `fvm dart format lib` |

**IDE setup:**
- **VS Code:** already set up. [`.vscode/settings.json`](.vscode/settings.json) points the Dart extension at `.fvm/flutter_sdk`. Reload the window after running `fvm install`.
- **Android Studio:** *Settings ▸ Languages & Frameworks ▸ Flutter ▸ Flutter SDK path* → `<project>/.fvm/flutter_sdk`

To upgrade Flutter later: `fvm use <version>` (e.g. `fvm use stable`). This updates `.fvmrc`; then commit it.

> `.fvm/` is a local cache/symlink and is git-ignored. Only `.fvmrc` needs to be shared.
>
> Not using FVM? Plain `flutter` 3.47.5+ works too; just drop the `fvm` prefix in the commands below.

### Run
```bash
fvm flutter pub get
fvm flutter run
```
The first build takes a few minutes. The app needs an internet connection, since songs, artwork and lyrics all stream from the network.

To see the onboarding screen again, uninstall the app (onboarding is shown only on first launch).

### Test
```bash
fvm flutter analyze
fvm flutter test
```

---

## Project structure

```
lib/
├── main.dart                     # App entry: background audio init + providers
├── core/theme/
│   └── app_theme.dart            # Colors, fonts, light/dark themes, ThemedScreen
├── data/                         # No Flutter UI code in here
│   ├── models.dart               # Track, Artist, Album, Mix, UserPlaylist, Lyrics
│   ├── music_repository.dart     # Interface the UI talks to
│   ├── jiosaavn_repository.dart  # JioSaavn implementation (+ request cache)
│   ├── lyrics_repository.dart    # LRCLIB lyrics (synced + plain)
│   └── catalog.dart              # Curated mixes, genres, artists (edit freely)
├── state/                        # ChangeNotifiers (provider)
│   ├── player_controller.dart    # just_audio player + queue, shuffle, repeat
│   ├── library_controller.dart   # Likes, playlists, follows → shared_preferences
│   └── accent_controller.dart    # Picks each song's colors from its album art
└── ui/
    ├── navigation.dart           # All screen-to-screen navigation
    ├── screens/                  # One file per screen
    └── widgets/                  # Artwork, TrackTile, MiniPlayer, waveform, …
test/
├── widget_test.dart              # Mix building, JSON, formatters
└── playlist_dialog_test.dart     # Create-playlist dialog regression test
```

### How it fits together
- **The UI never calls an API directly.** Screens ask `MusicRepository` for plain app models (`Track`, `AlbumSummary`, …), so the music source can be swapped without touching the UI.
- **State** is handled by three `ChangeNotifier`s shared with `provider`:
  - `PlayerController` owns a single `AudioPlayer`. Its `queue` always matches the player's play order, so the Queue screen can show and reorder it directly.
  - `LibraryController` stores the user's data as JSON in `shared_preferences`.
  - `AccentController` watches the current song and produces its colors.
- **Theming:** each screen is wrapped in `ThemedScreen(dark: true/false)`. Read colors with `context.palette` (`bg`, `fg`, `muted`, `surface`, `border`, `accent`, `accentDeep`).

---

## Design system

| Token | Value | Used for |
|---|---|---|
| Ink | `#0E0E0E` | Dark backgrounds, text on light screens |
| Paper | `#ECE9E2` | Light backgrounds, text on dark screens |
| Lime | `#D9F21E` | Default accent (until a song plays) |
| Display font | Bebas Neue | Big headlines ("DISCOVER") |
| UI font | Inter | Everything else |
| Mono font | JetBrains Mono | Lyrics |

Fonts load at runtime through `google_fonts`.

### Per-song colors
`AccentController` downsamples the album art, groups its colorful pixels by hue, and picks the hue that covers the most of the cover. Greys, blacks, whites and most skin tones are ignored. From that hue it makes two colors:
- **accent**: a bright, saturated tone (pills, waveform, hearts, play buttons, progress bars)
- **deep**: a very dark shade (Now Playing / Queue background, mini player)

Black-and-white covers get a color from a small neon palette instead, and the same song always gets the same color. On light screens, text and icons stay ink-colored for readability.

---

## Customizing

- **Home / Search content:** edit [`lib/data/catalog.dart`](lib/data/catalog.dart). Each mix is a list of search queries whose results are interleaved and de-duplicated. JioSaavn search mostly matches song titles, so **artist names work best** as queries.
- **Colors and fonts:** [`lib/core/theme/app_theme.dart`](lib/core/theme/app_theme.dart)
- **Onboarding image:** add `assets/images/onboarding_hero.png`. Until then, a headphones icon is shown.
- **App name:** currently "Pulse". Change it in `lib/main.dart` (`title`), `android/app/src/main/AndroidManifest.xml` (`android:label`) and `ios/Runner/Info.plist` (`CFBundleDisplayName`).

### Switching the music source
Implement `MusicRepository` for another provider and swap it in `main.dart`:
```dart
Provider<MusicRepository>(create: (_) => JioSaavnRepository()),
```
Legal options for a public release:
- [Jamendo API](https://developer.jamendo.com/): free, full-length Creative Commons tracks (free API key)
- [Audius API](https://docs.audius.org/): free, full streams allowed
- Deezer / iTunes Search API: free, but only 30-second previews

---

## Main packages

| Package | Why |
|---|---|
| `jiosaavn` | JioSaavn search, songs, albums, artists (unofficial) |
| `just_audio` + `just_audio_background` | Playback, playlist queue, background audio + lock-screen controls |
| `provider` | State management |
| `cached_network_image` | Artwork loading + caching |
| `google_fonts` | Bebas Neue, Inter, JetBrains Mono |
| `dio` | HTTP for LRCLIB lyrics |
| `shared_preferences` | Saving the user's library on device |
| `material_color_utilities` | Color extraction for the per-song theme |

Lyrics come from [LRCLIB](https://lrclib.net), a free, open lyrics database. No API key is needed.

---

## Known limitations

- **Unofficial API:** JioSaavn can change or block its endpoints at any time, which would break search and playback.
- **Mixes are search-based:** the package doesn't expose JioSaavn playlists, so "Chill Mix", the genres and so on are built from searches, and results can sometimes be off-topic.
- **Lyrics** aren't available for every song, especially regional tracks.
- **Library is stored on the device only:** there are no accounts and no sync. Uninstalling the app deletes it.
- **Not tested on Android** (Android is configured, but the app has only been run on the iOS Simulator so far).

## License

For personal learning use only. See the disclaimer at the top.
