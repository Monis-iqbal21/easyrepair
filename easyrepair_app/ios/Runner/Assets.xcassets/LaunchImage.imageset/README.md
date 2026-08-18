# HandyGo launch image

`LaunchImage.png` / `@2x` / `@3x` are the HandyGo logo lockup (icon + wordmark
+ "(Private) Limited" + the "Har maslay ka ustaad" tagline), generated from
`assets/images/handygo_logo.png` at 192 / 384 / 576 px wide. They keep the
source asset's 3:2 aspect ratio and its transparency, so the logo sits on the
launch screen's background colour with no visible box.

## Native fallback colour — single source of truth for iOS

The iOS launch background colour is defined in exactly one place:

    ios/Runner/Base.lproj/LaunchScreen.storyboard
        -> the root view's `backgroundColor`

It is currently **#FDFAF6** (sRGB 0.99216, 0.98039, 0.96471), matching the
flat near-white canvas in the middle/bottom of `assets/images/background.png`
— the region the Flutter welcome screen shows behind the logo and the
"Shuru karein" button. Keeping the two equal is what removes the white flash
between the iOS launch screen and Flutter's first frame.

The Android counterpart is `@color/handygo_splash_background` in
`android/app/src/main/res/values/colors.xml`.

## Why the launch screen is not the full background artwork

`background.png` is a fixed-aspect illustration. Stretching it across every
iOS device would crop differently from Flutter's `BoxFit.cover`, which reads
as a jump at hand-off. The launch screen therefore shows the flat colour plus
the centred logo; the full artwork appears the instant Flutter draws.

## When the final HandyGo palette is chosen

Update the storyboard `backgroundColor` above and the Android colour named
alongside it. No other file needs to change.
