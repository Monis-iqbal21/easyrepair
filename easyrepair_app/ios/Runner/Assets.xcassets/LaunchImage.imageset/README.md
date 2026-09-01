# HandyGo launch image

`LaunchImage.png` / `@2x` / `@3x` are the HandyGo **wrench mark alone**,
generated from `assets/images/logo-final.png` at 120 / 240 / 360 px. The source
is trimmed to the mark and re-padded to an exact square, so all three sizes are
the same 120pt square, centred, at the asset's own aspect ratio — never
stretched. The mark keeps its transparency and its off-white colour, so it sits
directly on the launch screen's background with no box behind it.

Deliberately **no wordmark and no tagline**: "HandyGo" and "Har maslay ka
ustaad" are real Flutter `Text` on the loading/welcome screen that follows, so
they scale with the device and the user's text-size setting.

## Native splash colour — single source of truth for iOS

The iOS launch background colour is defined in exactly one place:

    ios/Runner/Base.lproj/LaunchScreen.storyboard
        -> the root view's `backgroundColor`

It is **#082B28** (sRGB 0.03137, 0.16863, 0.15686) — HandyGo's startup teal,
the deep end of the brand teal that the primary `#11645D` sits in. Flutter then
paints its own loading/welcome screen in that primary teal, so the hand-off is
one step within a single hue rather than a flash between unrelated colours.

Native launch resources cannot read Flutter's runtime theme, so this literal is
deliberate and correct here: it is the platform counterpart of
`lib/core/theme/app_semantic_colors.dart`, not a colour escaping the design
system. The Android counterpart is `@color/handygo_splash_background` in
`android/app/src/main/res/values/colors.xml`.

## When the palette moves

Update the storyboard `backgroundColor` above and the Android colour named
alongside it. No other file needs to change.
