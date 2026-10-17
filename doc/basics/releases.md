# Releases

- [Introduction](#introduction)
- [Enabling Releases](#enabling-releases)
- [The Releases Feed](#the-releases-feed)
- [The Changelog Page](#the-changelog-page)
- [The Version Caption](#the-version-caption)
- [The Update Banner](#the-update-banner)
- [Web](#web)
- [iOS and Android](#ios-and-android)
- [Translations](#translations)

<a name="introduction"></a>
## Introduction

Two opt-in features tell customers what changed and when a newer build is waiting for them. `releases` adds a "What's new" page, a row for it on the settings hub and a version caption. `app_update` adds a banner that offers the newest build without interrupting what the customer is doing. Both read the same endpoint of `magic-starter-laravel`, `GET releases`, which anyone can call, signed in or not.

<a name="enabling-releases"></a>
## Enabling Releases

Turn the features on in `lib/config/magic_starter.dart`:

```dart
'features': {
  'releases': true,
  'app_update': true,
},
```

Both default to `false`, and you can enable either one alone. The backend has to enable `Features::releases()` in `config/magic-starter.php` as well. With it off the endpoint answers 404: the changelog page shows its error state and the banner stays quiet. The client reads no flag from the backend, so the two sides are switched on separately.

`registerMagicStarterProfileRoutes()` registers the changelog route, like every other settings page, so a host that already calls it adds nothing else.

<a name="the-releases-feed"></a>
## The Releases Feed

The client reads one body, newest release first, 50 at most:

```json
{
  "data": [
    {
      "version": "1.1.0",
      "published_at": "2026-10-20T09:00:00.000000Z",
      "ios_build": 15,
      "android_build": 15,
      "items": [
        { "type": "new", "text": { "en": "Dark mode", "tr": "Koyu tema" } }
      ]
    }
  ],
  "meta": {
    "latest_build": { "ios": 15, "android": 15 }
  }
}
```

An item's `type` is `new`, `improved` or `fixed`; an item with any other type is skipped, so an older app keeps working when the backend learns a new one. `text` carries one entry per language the backend supports. The page shows the reader's own language, then `magic_starter.defaults.locale`, then the first entry that is not empty. `published_at`, `ios_build`, `android_build` and both `latest_build` values may be `null`.

`MagicStarterReleasesController` reads it. `readFeed()` is the stateless read the banner uses and answers `null` on any failure; `fetchReleases()` loads the feed into the controller state for the page.

<a name="the-changelog-page"></a>
## The Changelog Page

With `releases` on, the settings hub gets a "What's new" row in its Preferences section, and the page opens at `/settings/changelog` (`MagicStarterConfig.settingsChangelogRoute()`, which follows `profile_prefix`). It is pushed (`.stacked()`), so the back gesture returns to the hub.

Each release is a card with its version, its date and one line per change, tagged with a New, Improved or Fixed badge. A failed read shows an error state with "Try again", and a feed with no releases shows an empty state.

The view key is `settings.changelog`. Replace the page the usual way:

```dart
MagicStarter.view.register('settings.changelog', () => const MyChangelogView());
```

<a name="the-version-caption"></a>
## The Version Caption

`MagicStarterAppVersion` is a one-line caption naming the build the app runs. The settings hub and the changelog page show it when `releases` is on. A host that wants it elsewhere, in its own footer or drawer, places the widget itself:

```dart
const MagicStarterAppVersion()
```

The label is `1.0.0 (14)` on iOS and Android, where `14` is the build number, and `1.0.0 · <build>` on the web. It shows only the version when the build number is empty. Pass `className` to replace the default style (`text-xs text-fg-muted text-center`). The widget renders nothing while the read is pending and when the platform cannot answer.

The support conversation's client info reads the same package info, so the caption and the report always agree.

> [!NOTE]
> A web build reports the `--build-number` you give `flutter build web`, written into `version.json` as `build_number`. Pass the deploy sha there, so the caption and the update banner have something to tell two deploys apart:
>
> ```bash
> flutter build web --release --build-number="$GITHUB_SHA"
> ```

<a name="the-update-banner"></a>
## The Update Banner

`MagicStarterAppUpdateBanner` is a non-modal strip with a message, one action and "Later". The shipped app layout mounts it when `app_update` is on. A host with its own layout places it by hand, near the top of the content:

```dart
const MagicStarterAppUpdateBanner()
```

It checks once after mounting and again whenever the app resumes, at most once per 15 minutes (`MagicStarterAppUpdateBanner.checkInterval`). It never reloads by itself and never opens a dialog.

"Later" remembers the offered build in the `Vault` under `magic_starter.app_update.dismissed_build`, so the banner stays hidden for that build and returns only for a newer one. If the write fails, the banner is still hidden for the rest of the session.

A check that cannot read a build (no network, a refusal, an unreadable store) logs a warning and leaves the banner as it was. Desktop, debug and profile builds, and an app with `app_update` off, render nothing and start no timer.

<a name="web"></a>
## Web

On the web the banner compares the build the page is running with the `build_number` in the `version.json` the server serves now. It polls every 15 minutes and on resume, which a browser reports when the tab comes back to the front.

A difference is not shown at once. The banner waits 60 seconds from the moment it first sees the new build (`MagicStarterAppUpdateBanner.revealDelay`), so a deploy that is still rolling out does not flash it at every customer. The action is "Reload", which reloads the page.

The check needs a build number on both sides, so it stays quiet when `version.json` is missing. A build made without `--build-number` carries the pubspec build number instead, which stays the same from one deploy to the next, so the banner cannot tell two such deploys apart. The running build is read once, at boot, and kept for the life of the page: a later first read could already see the next deploy and report it as the one that is loaded.

Serve `index.html`, `main.dart.js`, `flutter_bootstrap.js` and `version.json` with `Cache-Control: no-cache`. If a CDN or the browser answers with an old copy, "Reload" loads the old bundle and the banner comes straight back. An nginx server block:

```nginx
location ~* ^/(index\.html|main\.dart\.js|flutter_bootstrap\.js|version\.json)$ {
    add_header Cache-Control "no-cache";
}
```

<a name="ios-and-android"></a>
## iOS and Android

On a phone the banner compares the installed build number with `meta.latest_build` from the feed (`ios` or `android`) and shows at once when the store build is higher. It checks on mount and on resume, at most once per 15 minutes; there is no periodic timer.

It only looks at release builds installed from the store: the App Store (installer `com.apple`) and Google Play (`com.android.vending`). TestFlight, the simulator, a debug build and a sideload stay quiet, since a store build would not replace them.

"Update" opens the store page:

| Platform | Opens |
|----------|-------|
| iOS | `https://apps.apple.com/app/id<app_store_id>` |
| Android | `https://play.google.com/store/apps/details?id=<package>` |

iOS needs the App Store id, the same one the store review feature reads (the `store_review` feature itself can stay off):

```dart
'store_review': {
  'app_store_id': '1234567890',
},
```

Without it the iOS banner stays hidden and logs a warning.

The banner stays quiet until the backend publishes a release with a build number for the platform. A build that is not a plain number, on either side, is never counted as newer.

<a name="translations"></a>
## Translations

The copy lives under `magic_starter.releases.*`, `magic_starter.app_update.*` and `magic_starter.titles.changelog`. `starter:publish --tag=lang` never overwrites a catalogue the host already has, so an existing app merges the new keys by hand from `assets/stubs/install/en.stub`. A missing key shows as the key itself.
