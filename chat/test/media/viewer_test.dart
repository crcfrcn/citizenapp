// 归并聊天原有回归，保留各来源用例、断言及独立生命周期。

import 'package:chat/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

// 验证拍摄页手势提示及三分钟录像上限。

void _registerCameraCapture() {
  test('应用内录像唯一上限为三分钟', () {
    expect(CameraCapturePage.maximumVideoDuration, const Duration(minutes: 3));
  });

  testWidgets('拍摄页明确展示点按拍照和长按录像手势', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CameraCapturePage()));
    await tester.pump();
    expect(find.text('点按拍照，长按录像'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-camera-shutter')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

// 验证全屏图片查看结构及保存成功和失败提示。

// 用不存在的路径:widget 测试里解码真实图片会挂起 fake-async 时钟;errorBuilder
// 同步渲染占位,足以验证结构与保存流程。真实内联渲染以真机/集成为准。
void _registerImageViewerPage() {
  testWidgets('ImageViewerPage 结构完整,保存按钮调用注入 saver 并提示成功', (tester) async {
    String? savedPath;
    String? savedName;
    await tester.pumpWidget(
      MaterialApp(
        home: ImageViewerPage(
          filePath: '/tmp/gmb-viewer-none.png',
          fileName: 'photo.png',
          onSaveToGallery: ({required filePath, required fileName}) async {
            savedPath = filePath;
            savedName = fileName;
            return true;
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.byIcon(Icons.download_rounded));
    await tester.pump();

    expect(savedPath, '/tmp/gmb-viewer-none.png');
    expect(savedName, 'photo.png');
    expect(find.text('已保存到相册'), findsOneWidget);
  });

  testWidgets('ImageViewerPage 保存失败时提示失败', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ImageViewerPage(
          filePath: '/tmp/gmb-viewer-none2.png',
          fileName: 'none.png',
          onSaveToGallery: ({required filePath, required fileName}) async =>
              false,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.download_rounded));
    await tester.pump();
    expect(find.text('保存失败'), findsOneWidget);
  });
}

// 验证九图或单视频选择、取消及混选和非法文件拒绝。

void _registerMediaPicker() {
  Future<List<PickedMediaFile>> pick(
    WidgetTester tester,
    List<XFile> files,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    return MediaPicker(pickGallery: (_) async => files).gallery(context);
  }

  testWidgets('相册一次可返回一至九张照片并保持顺序', (tester) async {
    final files = [
      for (var index = 0; index < 9; index++) XFile('/tmp/photo-$index.jpg'),
    ];
    final result = await pick(tester, files);
    expect(result, hasLength(9));
    expect(result.every((item) => item.kind == ChatMessageKind.image), isTrue);
    expect(result.first.fileName, 'photo-0.jpg');
    expect(result.last.fileName, 'photo-8.jpg');
  });

  testWidgets('相册一次可返回一个视频', (tester) async {
    final result = await pick(tester, [XFile('/tmp/clip.mp4')]);
    expect(result.single.kind, ChatMessageKind.video);
    expect(result.single.mime, 'video/mp4');
  });

  testWidgets('取消相册返回空列表', (tester) async {
    expect(await pick(tester, const []), isEmpty);
  });

  testWidgets('图片与视频混选失败关闭', (tester) async {
    expect(
      () => pick(tester, [XFile('/tmp/photo.jpg'), XFile('/tmp/clip.mp4')]),
      throwsA(isA<FormatException>()),
    );
  });

  testWidgets('十张照片超过上限失败关闭', (tester) async {
    expect(
      () => pick(tester, [
        for (var index = 0; index < 10; index++) XFile('/tmp/photo-$index.jpg'),
      ]),
      throwsA(isA<FormatException>()),
    );
  });

  testWidgets('非图片视频文件失败关闭', (tester) async {
    expect(
      () => pick(tester, [XFile('/tmp/document.pdf')]),
      throwsA(isA<FormatException>()),
    );
  });

  testWidgets('XFile 自带 MIME 优先采用', (tester) async {
    final result = await pick(tester, [
      XFile('/tmp/noext', mimeType: 'image/png'),
    ]);
    expect(result.single.mime, 'image/png');
    expect(result.single.kind, ChatMessageKind.image);
  });
}

// 验证语音上限及未下载消息使用既有附件入口。

void _registerVoiceMessagePlayer() {
  test('语音单条唯一上限为三分钟', () {
    expect(VoiceRecorder.defaultMaximumDuration, const Duration(minutes: 3));
  });

  testWidgets('未到达的语音气泡显示下载入口并走既有附件回调', (tester) async {
    var downloads = 0;
    const message = Message.audio(
      id: 'audio-1',
      authorId: 'peer',
      source: '',
      duration: Duration(seconds: 12),
    ) as AudioMessage;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceMessagePlayer(
            message: message,
            isSentByMe: false,
            onRequestDownload: () async => downloads += 1,
          ),
        ),
      ),
    );

    expect(find.text('12″'), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-audio-audio-1')));
    await tester.pump();
    expect(downloads, 1);
  });
}

void main() {
  group("conversation/camera_capture_test", _registerCameraCapture);
  group("conversation/image_viewer_page_test", _registerImageViewerPage);
  group("conversation/media_picker_test", _registerMediaPicker);
  group("conversation/voice_message_player_test", _registerVoiceMessagePlayer);
}
