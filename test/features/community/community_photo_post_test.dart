import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_travel_planner/features/community/community_page.dart';
import 'package:smart_travel_planner/features/community/community_service.dart';
import 'package:smart_travel_planner/features/community/widgets/citylore_post_card.dart';

class _PhotoPicker extends ImagePicker {
  static final photo = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/rZkAAAAASUVORK5CYII=',
  );

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async => [XFile.fromData(photo, name: 'photo.png', mimeType: 'image/png')];
}

class _PublishingService extends CommunityService {
  List<Uint8List>? received;
  List<String>? retained;
  String? publishedBody;

  @override
  Future<void> publish({
    required String id,
    required String body,
    required String place,
    required String topic,
    List<Uint8List> photos = const [],
  }) async {
    received = photos;
    publishedBody = body;
  }

  @override
  Future<void> updatePost({
    required String id,
    required String body,
    required String place,
    required String topic,
    required List<String> retainedPaths,
    List<Uint8List> newPhotos = const [],
  }) async {
    retained = retainedPaths;
    received = newPhotos;
  }
}

void main() {
  testWidgets('share to Community publishes a credited repost', (tester) async {
    final service = _PublishingService();
    final post = CommunityPost(
      id: 'original',
      author: 'Amina',
      place: 'Penang',
      topic: 'Trip Log',
      body: 'A lovely visit',
      date: '2026-11-19',
      likesCount: 0,
      liked: false,
      saved: false,
      comments: const [],
    );
    var refreshed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => shareCommunityPost(
                context,
                post,
                service: service,
                onCommunityShared: () => refreshed = true,
              ),
              child: const Text('Share'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share to Community'));
    await tester.pumpAndSettle();
    expect(service.publishedBody, isNull);
    await tester.enterText(find.byType(TextField), 'This is worth visiting.');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Share post'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Share post'));
    await tester.pumpAndSettle();
    expect(
      service.publishedBody,
      'This is worth visiting.\n\nShared Amina’s post\n\nA lovely visit\n\n[community-source:original]',
    );
    expect(refreshed, isTrue);
  });

  test(
    'Community repost credits the original author within the post limit',
    () {
      final post = CommunityPost(
        id: 'original',
        author: 'Amina',
        place: 'Penang',
        topic: 'Trip Log',
        body: 'A' * 2000,
        date: '2026-11-19',
        likesCount: 0,
        liked: false,
        saved: false,
        comments: const [],
      );
      final body = communityRepostBody(post, note: 'Visit this place');
      expect(body, startsWith('Visit this place\n\nShared Amina’s post\n\n'));
      expect(body.runes.length, 2000);
      final parts = communityRepostParts(body)!;
      expect(parts.thought, 'Visit this place');
      expect(parts.author, 'Amina');
      expect(parts.sourceId, 'original');
      expect(parts.original, isNot(contains('community-source')));
    },
  );

  test('Community feed retains published photo paths', () {
    final post = CommunityPost.fromFeed({
      'id': 'post-id',
      'author': 'Traveller',
      'place': 'Putrajaya',
      'topic': 'Photo',
      'body': 'A lovely visit',
      'created_at': '2026-11-18T10:00:00Z',
      'likes_count': 0,
      'liked': false,
      'saved': false,
      'comments': [],
      'photo_paths': ['user/post/0.jpg'],
    });
    expect(post.photoPaths, ['user/post/0.jpg']);
  });

  testWidgets('composer sends selected photo bytes when publishing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = _PublishingService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityComposer(
            service: service,
            imagePicker: _PhotoPicker(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'A lovely visit');
    await tester.tap(find.byKey(const ValueKey('community-place-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this place'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Add photos').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Publish post'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Publish post'));
    await tester.pump();
    expect(service.received, hasLength(1));
    expect(service.received!.single, _PhotoPicker.photo);
  });

  testWidgets('owner can remove an existing photo while editing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = _PublishingService();
    final post = CommunityPost(
      id: 'post-id',
      author: 'Traveller',
      place: 'Putrajaya',
      topic: 'Photo',
      body: 'A lovely visit',
      date: '2026-11-18',
      likesCount: 0,
      liked: false,
      saved: false,
      comments: const [],
      isMine: true,
      photoPaths: const ['user/post/0.png'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityComposer(service: service, editing: post),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Edit post'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byTooltip('Remove photo'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Remove photo'));
    await tester.scrollUntilVisible(
      find.text('Save changes'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(service.retained, isEmpty);
  });

  testWidgets('post card reserves space for published photos', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final post = CommunityPost(
      id: 'post',
      author: 'Traveller',
      place: 'Putrajaya',
      topic: 'Photo',
      body: 'A lovely visit',
      date: '2026-11-18',
      likesCount: 0,
      liked: false,
      saved: false,
      comments: const [],
      photoPaths: const ['photo.jpg'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CitylorePostCard(
            post: post,
            onToggleLike: () {},
            onToggleSave: () {},
            onOpenDetail: () {},
          ),
        ),
      ),
    );
    expect(find.byType(CommunityPostPhotos), findsOneWidget);
    expect(find.byTooltip('Share post'), findsOneWidget);
    expect(find.text('Read story'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets(
    'shared post shows thought before credited original and opens profiles',
    (tester) async {
      final source = CommunityPost(
        id: 'source-post',
        author: 'Ching Kheat',
        place: 'Putrajaya',
        topic: 'Trip Log',
        body: 'A lovely visit',
        date: '2026-11-19',
        likesCount: 0,
        liked: false,
        saved: false,
        comments: const [],
      );
      final shared = CommunityPost(
        id: 'shared-post',
        author: 'Yihan',
        place: source.place,
        topic: source.topic,
        body: communityRepostBody(source, note: 'I want to visit.'),
        date: '2026-11-19',
        likesCount: 0,
        liked: false,
        saved: false,
        comments: const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitylorePostCard(
              post: shared,
              onToggleLike: () {},
              onToggleSave: () {},
              onOpenDetail: () {},
            ),
          ),
        ),
      );
      expect(find.text('I want to visit.'), findsOneWidget);
      expect(find.text('Shared Ching Kheat’s post'), findsOneWidget);
      expect(find.text('A lovely visit'), findsOneWidget);
      await tester.tap(find.text('Yihan'));
      await tester.pumpAndSettle();
      expect(find.text('Community member'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shared Ching Kheat’s post'));
      await tester.pumpAndSettle();
      expect(find.text('Ching Kheat'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
    },
  );

  testWidgets('authenticated photo bytes render in the post', (tester) async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/rZkAAAAASUVORK5CYII=',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityPostPhotos(
            paths: const ['owned-photo.png'],
            photoLoader: (_) async => png,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Photo'), findsOneWidget);
  });
}
