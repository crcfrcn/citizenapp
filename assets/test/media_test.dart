import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('所有声明的公民图片和SVG资源均真实可读', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final images = manifest.listAssets().where((key) =>
        key.startsWith('packages/citizen_assets/') &&
        (key.endsWith('.png') || key.endsWith('.jpg') || key.endsWith('.svg')));
    expect(images, isNotEmpty);
    for (final key in images) {
      final data = await rootBundle.load(key);
      expect(data.lengthInBytes, greaterThan(0), reason: key);
      if (key.endsWith('.svg')) {
        expect(await rootBundle.loadString(key), contains('<svg'), reason: key);
      } else {
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0), reason: key);
        expect(frame.image.height, greaterThan(0), reason: key);
        frame.image.dispose();
        codec.dispose();
      }
    }
  });
  test('两份字体原件随资源包交付', () async {
    for (final name in ['LXGWWenKaiLite-Regular.ttf', 'FZJingLeiS-R-GB.ttf']) {
      final bytes = await rootBundle.load('packages/citizen_assets/fonts/$name');
      expect(bytes.lengthInBytes, greaterThan(12), reason: name);
    }
  });
}
