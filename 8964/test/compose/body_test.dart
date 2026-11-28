// 归并广场原有回归，保留各来源用例、断言及独立生命周期。

import 'package:citizen_square/compose/body.dart';
import 'package:citizen_square/compose/media.dart';
import 'package:citizen_square/post/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

// 验证公文字数、非空及图片上限和删除后补选。

class _ImagePickerFake extends ComposeMediaPicker {
  _ImagePickerFake(this.files);

  final List<XFile> files;
  int callCount = 0;
  final List<int> requestedLimits = [];

  @override
  Future<List<XFile>> pickImages(BuildContext context, int maxImages) async {
    callCount += 1;
    requestedLimits.add(maxImages);
    return files;
  }

  @override
  Future<List<ComposePickedMedia>> pickArticleMedia(BuildContext context) =>
      throw UnimplementedError();
}

SquareLocalMediaDraft _draftFor(XFile file) => SquareLocalMediaDraft(
  mediaKind: SquareMediaKind.image,
  path: file.path,
  fileName: file.name,
  contentType: 'image/jpeg',
  byteSize: 1,
);

void _registerDocumentComposeBody() {
  testWidgets('公文支持纯文字并固定300字上限', (tester) async {
    final key = GlobalKey<SquareDocumentComposeBodyState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SquareDocumentComposeBody(key: key, initialText: '公文正文'),
        ),
      ),
    );

    final valid = key.currentState!.collect();
    expect(valid.isValid, isTrue);
    expect(valid.text, '公文正文');
    expect(valid.mediaDrafts, isEmpty);

    final overflowKey = GlobalKey<SquareDocumentComposeBodyState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SquareDocumentComposeBody(
            key: overflowKey,
            initialText: '甲' * (documentTextMax + 1),
          ),
        ),
      ),
    );
    expect(overflowKey.currentState!.collect().error, '公文文字不能超过300字');
  });

  testWidgets('公文不允许空内容', (tester) async {
    final key = GlobalKey<SquareDocumentComposeBodyState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SquareDocumentComposeBody(key: key)),
      ),
    );

    expect(key.currentState!.collect().error, '公文内容不能为空');
  });

  testWidgets('公文选择器和本地状态双重限制最多9张', (tester) async {
    final key = GlobalKey<SquareDocumentComposeBodyState>();
    final picker = _ImagePickerFake(
      List<XFile>.generate(12, (index) => XFile('/tmp/image-$index.jpg')),
    );
    final counts = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SquareDocumentComposeBody(
            key: key,
            mediaPicker: picker,
            mediaDraftBuilder: (file, mediaKind) async => _draftFor(file),
            onMediaCountChanged: counts.add,
          ),
        ),
      ),
    );
    await tester.pump();

    await key.currentState!.pickImages();

    expect(picker.requestedLimits.single, documentMaxImages);
    expect(
      key.currentState!.collect().mediaDrafts,
      hasLength(documentMaxImages),
    );
    expect(counts.last, documentMaxImages);

    // 达到上限后不再唤起系统相册，防止继续选择。
    await key.currentState!.pickImages();
    expect(picker.callCount, 1);
  });

  testWidgets('公文9张删除1张后可立即补选1张', (tester) async {
    final key = GlobalKey<SquareDocumentComposeBodyState>();
    final picker = _ImagePickerFake(
      List<XFile>.generate(12, (index) => XFile('/tmp/image-$index.jpg')),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SquareDocumentComposeBody(
            key: key,
            mediaPicker: picker,
            mediaDraftBuilder: (file, mediaKind) async => _draftFor(file),
          ),
        ),
      ),
    );
    await key.currentState!.pickImages();
    await tester.pump();
    await tester.tap(find.byType(ComposeMediaRemoveButton).first);
    await tester.pump();
    await key.currentState!.pickImages();

    expect(picker.requestedLimits, [9, 1]);
    expect(key.currentState!.collect().mediaDrafts, hasLength(9));
  });
}

// 验证单视频、配文字数及统一预览和删除交互。

const _video = SquareLocalMediaDraft(
  mediaKind: SquareMediaKind.video,
  path: '/tmp/video.mp4',
  fileName: 'video.mp4',
  contentType: 'video/mp4',
  byteSize: 1024,
  videoSecs: 30,
);

class _VideoPickerFake extends ImagePicker {
  @override
  Future<XFile?> pickVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async => XFile(_video.path);
}

void _registerVideoComposeBody() {
  testWidgets('视频发布必须且只带一个视频', (tester) async {
    final key = GlobalKey<SquareVideoComposeBodyState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SquareVideoComposeBody(
            key: key,
            initialText: '视频配文',
            initialMedia: const [_video],
          ),
        ),
      ),
    );

    final payload = key.currentState!.collect();
    expect(key.currentState!.isContentValid, isTrue);
    expect(payload.isValid, isTrue);
    expect(payload.text, '视频配文');
    expect(payload.mediaDrafts, const [_video]);
  });

  testWidgets('视频缺失或配文超过300字时拒绝', (tester) async {
    final emptyKey = GlobalKey<SquareVideoComposeBodyState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SquareVideoComposeBody(key: emptyKey)),
      ),
    );
    expect(emptyKey.currentState!.collect().error, '请选择1个视频');
    expect(emptyKey.currentState!.isContentValid, isFalse);

    final overflowKey = GlobalKey<SquareVideoComposeBodyState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SquareVideoComposeBody(
            key: overflowKey,
            initialText: '甲' * (videoTextMax + 1),
            initialMedia: const [_video],
          ),
        ),
      ),
    );
    expect(overflowKey.currentState!.collect().error, '视频配文不能超过300字');
    expect(overflowKey.currentState!.isContentValid, isFalse);
  });

  testWidgets('选中后显示真实视频区域并使用统一圆形叉号删除', (tester) async {
    final key = GlobalKey<SquareVideoComposeBodyState>();
    final changes = <SquareLocalMediaDraft?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SquareVideoComposeBody(
            key: key,
            imagePicker: _VideoPickerFake(),
            mediaDraftBuilder: (_, _) async => _video,
            onVideoChanged: changes.add,
          ),
        ),
      ),
    );
    await tester.pump();

    await key.currentState!.pickVideo();
    await tester.pump();

    expect(find.byType(ComposeLocalVideoPreview), findsOneWidget);
    expect(find.byType(ComposeMediaRemoveButton), findsOneWidget);
    expect(changes.last, _video);

    await tester.tap(find.byType(ComposeMediaRemoveButton));
    await tester.pump();
    expect(find.byType(ComposeLocalVideoPreview), findsNothing);
    expect(changes.last, isNull);
  });
}

void main() {
  group("compose/document_compose_body_test", _registerDocumentComposeBody);
  group("compose/video_compose_body_test", _registerVideoComposeBody);
}
