// Guards HandyGo's platform branding at the only level a device actually
// sees: the bytes of the generated native resources.
//
// Widget tests can only prove which asset NAME a screen asks for. The launcher
// icon, the native launch screen and the notification icon are never built by
// Flutter at all — they are PNGs under android/app/src/main/res and
// ios/Runner/Assets.xcassets, and a screen test cannot tell whether those are
// HandyGo's teal or EasyRepair's retired orange. This decodes them.
//
// The approved source is assets/images/logo-final.png: a brand-teal tile
// carrying an off-white wrench. Two failure modes are checked, because both
// have shipped before:
//
//   1. the retired orange coming back, and
//   2. the icon being INVERTED — a teal mark on an off-white tile, which is
//      not HandyGo's branding however teal it is.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _androidRes = 'android/app/src/main/res';
const _iosAssets = 'ios/Runner/Assets.xcassets';

/// EasyRepair's retired brand orange, and the family around it.
bool _isRetiredOrange(int r, int g, int b) =>
    r > 130 && r - g > 45 && g - b > 10;

/// HandyGo's brand teal #11645D, allowing for resampling and quantisation.
bool _isBrandTeal(int r, int g, int b) =>
    r < 90 && g > 60 && g < 150 && b > 55 && b < 145 && (g - b).abs() < 45;

bool _isOffWhite(int r, int g, int b) => r > 225 && g > 225 && b > 225;

class _Pixels {
  _Pixels(this.rgba);

  final Uint8List rgba;

  /// Fractions of the OPAQUE pixels matching each brand test.
  ({double orange, double teal, double offWhite, int opaque}) get profile {
    var orange = 0, teal = 0, offWhite = 0, opaque = 0;
    for (var i = 0; i < rgba.length; i += 4) {
      final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2], a = rgba[i + 3];
      if (a < 32) continue;
      opaque++;
      if (_isRetiredOrange(r, g, b)) orange++;
      if (_isBrandTeal(r, g, b)) teal++;
      if (_isOffWhite(r, g, b)) offWhite++;
    }
    final n = opaque == 0 ? 1 : opaque;
    return (
      orange: orange / n,
      teal: teal / n,
      offWhite: offWhite / n,
      opaque: opaque,
    );
  }
}

Future<_Pixels> _decode(String path) async {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'missing platform resource: $path');
  final codec = await ui.instantiateImageCodec(await file.readAsBytes());
  final image = (await codec.getNextFrame()).image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return _Pixels(data!.buffer.asUint8List());
}

const _densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the retired orange is gone from the repo', () {
    test('no legacy EasyRepair or orange-era logo file is still shipped', () {
      // assets/images/ is bundled wholesale by the `assets:` wildcard in
      // pubspec.yaml, so a file left lying here rides into every APK and IPA
      // whether or not any Dart code names it. Deleting them was the fix; this
      // stops them being restored.
      for (final retired in const [
        'easyrepair_logo.png',
        'easyrepair_logo-orange.png',
        'er-icon.png',
        'handygo_logo.png',
        'logo-green.png',
        'logo-green2.png',
        'logo-white.png',
        'logo-only.png',
        'banner.png',
        'logo-launcher-offwhite.png',
      ]) {
        expect(
          File('assets/images/$retired').existsSync(),
          isFalse,
          reason: '$retired is retired orange-era branding — do not restore it',
        );
      }
    });

    test('the approved source and everything derived from it are present', () {
      for (final kept in const [
        'logo-final.png', // the approved source
        'logo-app-icon.png', // tile + mark, for the launcher
        'logo-adaptive-foreground.png', // mark alone, Android adaptive
        'logo-onprimary-transparent.png', // mark alone, on the teal canvas
        'logo-primary-transparent.png', // teal mark, for light in-app surfaces
      ]) {
        expect(
          File('assets/images/$kept').existsSync(),
          isTrue,
          reason: 'assets/images/$kept is referenced by the build',
        );
      }
    });

    test('flutter_launcher_icons is pointed at the logo-final derivatives', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec,
        contains('image_path: "assets/images/logo-app-icon.png"'),
      );
      expect(
        pubspec,
        contains(
          'adaptive_icon_foreground: '
          '"assets/images/logo-adaptive-foreground.png"',
        ),
      );
      // The tile colour is the brand teal on both platforms.
      expect(pubspec, contains('adaptive_icon_background: "#11645D"'));
      expect(pubspec, contains('background_color_ios: "#11645D"'));
    });
  });

  group('no generated platform resource carries the retired orange', () {
    final resources = <String>[
      for (final d in _densities) ...[
        '$_androidRes/mipmap-$d/ic_launcher.png',
        '$_androidRes/drawable-$d/ic_launcher_foreground.png',
        '$_androidRes/drawable-$d/handygo_splash_logo.png',
        '$_androidRes/drawable-$d/ic_stat_handygo.png',
      ],
      '$_androidRes/drawable-nodpi/handygo_splash_icon.png',
      '$_iosAssets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      '$_iosAssets/AppIcon.appiconset/Icon-App-60x60@3x.png',
      '$_iosAssets/AppIcon.appiconset/Icon-App-76x76@2x.png',
      '$_iosAssets/LaunchImage.imageset/LaunchImage.png',
      '$_iosAssets/LaunchImage.imageset/LaunchImage@2x.png',
      '$_iosAssets/LaunchImage.imageset/LaunchImage@3x.png',
    ];

    for (final path in resources) {
      test(path, () async {
        final profile = (await _decode(path)).profile;
        expect(profile.opaque, greaterThan(0), reason: '$path is blank');
        expect(
          profile.orange,
          lessThan(0.005),
          reason: '$path still carries EasyRepair orange',
        );
      });
    }
  });

  group('the icon is the right way round', () {
    test(
      'the Android launcher tile is teal carrying an off-white mark',
      () async {
        // logo-final.png is a teal tile with an off-white wrench on it, so the
        // tile must dominate. If off-white dominated instead, the icon has
        // been inverted back into the unapproved off-white-tile treatment.
        final profile = (await _decode(
          '$_androidRes/mipmap-xxxhdpi/ic_launcher.png',
        )).profile;
        expect(
          profile.teal,
          greaterThan(0.5),
          reason: 'the launcher tile must be the brand teal',
        );
        expect(
          profile.offWhite,
          greaterThan(0.05),
          reason: 'the off-white wrench must be on it',
        );
        expect(
          profile.offWhite,
          lessThan(profile.teal),
          reason: 'launcher icon is inverted — off-white tile, teal mark',
        );
      },
    );

    test('the iOS app icon is opaque teal, with no alpha channel', () async {
      // The App Store rejects an icon carrying alpha, so the tile's rounded
      // corners are flattened onto the same teal and iOS applies its own mask.
      final pixels = await _decode(
        '$_iosAssets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      );
      for (var i = 3; i < pixels.rgba.length; i += 4) {
        expect(
          pixels.rgba[i],
          255,
          reason: 'iOS app icon must be fully opaque',
        );
      }
      expect(pixels.profile.teal, greaterThan(0.5));
    });

    test(
      'the launch drawables carry the off-white mark, never a teal one',
      () async {
        // The window behind them is already @color/handygo_splash_background,
        // so the mark must be the off-white one or it vanishes into the teal.
        for (final path in [
          '$_androidRes/drawable-xxxhdpi/handygo_splash_logo.png',
          '$_androidRes/drawable-nodpi/handygo_splash_icon.png',
          '$_iosAssets/LaunchImage.imageset/LaunchImage@3x.png',
        ]) {
          final profile = (await _decode(path)).profile;
          expect(
            profile.offWhite,
            greaterThan(0.9),
            reason: '$path must be the off-white mark on transparency',
          );
          expect(
            profile.teal,
            lessThan(0.02),
            reason: '$path is the inverted teal mark',
          );
        }
      },
    );

    test('the Android splash background and launcher tile are one colour', () {
      final colors = File('$_androidRes/values/colors.xml').readAsStringSync();
      expect(colors, contains('<color name="ic_launcher_background">#11645D<'));
      // The launch screen aliases the tile, so the launch window IS the icon.
      expect(
        colors,
        contains(
          '<color name="handygo_splash_background">'
          '@color/ic_launcher_background<',
        ),
      );
    });

    test('the iOS launch storyboard paints the same teal', () {
      final storyboard = File(
        'ios/Runner/Base.lproj/LaunchScreen.storyboard',
      ).readAsStringSync();
      // #11645D as the storyboard's own sRGB components.
      expect(storyboard, contains('red="0.066666666666666666"'));
      expect(storyboard, contains('green="0.39215686274509803"'));
      expect(storyboard, contains('blue="0.36470588235294116"'));
    });
  });

  group('Android notification small icon', () {
    // Android's technical exception. The status bar draws this as a mask: it
    // takes the alpha channel and paints it in the system's own colour, so any
    // colour baked in is either ignored or renders as a solid blob. It must be
    // a flat silhouette — but a silhouette of the APPROVED wrench, never a
    // leftover EasyRepair asset.
    for (final d in _densities) {
      test('$d is a white-on-transparent silhouette', () async {
        final pixels = await _decode(
          '$_androidRes/drawable-$d/ic_stat_handygo.png',
        );
        // rawRgba comes back premultiplied, so an antialiased edge pixel is
        // (a, a, a, a) rather than (255, 255, 255, a). Neutrality is the
        // property that matters: any hue at all means colour has been baked
        // into a resource the status bar is going to re-tint anyway.
        var solid = 0;
        for (var i = 0; i < pixels.rgba.length; i += 4) {
          final r = pixels.rgba[i], g = pixels.rgba[i + 1];
          final b = pixels.rgba[i + 2], a = pixels.rgba[i + 3];
          if (a < 32) continue;
          expect(r, g, reason: 'not monochrome — has a hue');
          expect(g, b, reason: 'not monochrome — has a hue');
          if (a == 255) {
            expect(r, 255, reason: 'the silhouette must be white');
            solid++;
          }
        }
        expect(solid, greaterThan(0), reason: 'silhouette is empty');
      });
    }

    test('the manifest points FCM at it, not at the full-colour launcher', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(
        manifest,
        contains('android:resource="@drawable/ic_stat_handygo"'),
        reason: 'FCM falls back to the launcher icon when this is missing',
      );
      expect(manifest, isNot(contains('@mipmap/ic_launcher_round')));
    });
  });
}
