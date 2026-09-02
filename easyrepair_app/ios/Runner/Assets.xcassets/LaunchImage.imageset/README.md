# HandyGo launch image

`LaunchImage.png` / `@2x` / `@3x` are the HandyGo **wrench mark alone**,
generated from `assets/images/logo-onprimary-transparent.png` at 120 / 240 /
360 px — which is itself the off-white wrench lifted, unrecoloured, off the
teal tile in the approved `assets/images/logo-final.png`. The source is trimmed
to the mark and re-padded to an exact square, so all three sizes are the same
120pt square, centred, at the asset's own aspect ratio — never stretched.

The mark keeps its transparency and its off-white colour, so it sits directly
on the storyboard's teal background with no box behind it. Background plus mark
therefore reproduce `logo-final.png`. A teal mark on an off-white launch screen
is the **inverse** of the approved icon and must not be reintroduced.

Deliberately **no wordmark and no tagline**: "HandyGo" and "Har maslay ka
ustaad" are real Flutter `Text` on the loading/welcome screen that follows, so
they scale with the device and the user's text-size setting.

## Native splash colour — single source of truth for iOS

The iOS launch background colour is defined in exactly one place:

    ios/Runner/Base.lproj/LaunchScreen.storyboard
        -> the root view's `backgroundColor`

It is **#11645D** (sRGB 0.06667, 0.39216, 0.36471) — HandyGo's brand teal, the
same value as the tile in `logo-final.png`. Flutter then paints its own
loading/welcome screen in that same primary teal, so the hand-off from native
launch to Flutter is invisible rather than a flash between two colours.

Native launch resources cannot read Flutter's runtime theme, so this literal is
deliberate and correct here: it is the platform counterpart of
`lib/core/theme/app_semantic_colors.dart`, not a colour escaping the design
system. The Android counterpart is `@color/handygo_splash_background` in
`android/app/src/main/res/values/colors.xml`.

## When the palette moves

Update the storyboard `backgroundColor` above and the Android colour named
alongside it. No other file needs to change.
