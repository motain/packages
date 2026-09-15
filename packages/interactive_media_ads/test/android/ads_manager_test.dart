// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:interactive_media_ads/src/android/android_ad_display_container.dart';
import 'package:interactive_media_ads/src/android/android_ads_manager.dart';
import 'package:interactive_media_ads/src/android/android_ads_manager_delegate.dart';
import 'package:interactive_media_ads/src/android/android_ads_rendering_settings.dart';
import 'package:interactive_media_ads/src/android/interactive_media_ads.g.dart' as ima;
import 'package:interactive_media_ads/src/platform_interface/platform_interface.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'ads_manager_test.mocks.dart';

@GenerateNiceMocks(<MockSpec<Object>>[
  MockSpec<ima.FrameLayout>(),
  MockSpec<ima.MediaPlayer>(),
  MockSpec<ima.VideoAdPlayer>(),
  MockSpec<ima.VideoView>(),
  MockSpec<ima.AdError>(),
  MockSpec<ima.AdErrorEvent>(),
  MockSpec<ima.AdErrorListener>(),
  MockSpec<ima.AdEvent>(),
  MockSpec<ima.AdEventListener>(),
  MockSpec<ima.AdsManager>(),
  MockSpec<ima.AdsRenderingSettings>(),
  MockSpec<ima.ImaSdkFactory>(),
])
void main() {
  setUp(() {
    ima.PigeonOverrides.pigeon_reset();
  });

  // `AndroidAdDisplayContainer` is a `base` class, so mockito cannot mock it.
  // These overrides are the minimum its constructor needs to build without a
  // platform view.
  AndroidAdDisplayContainer testContainer() {
    ima.PigeonOverrides.frameLayout_new = () => MockFrameLayout();
    ima.PigeonOverrides.videoView_new =
        ({required dynamic onError, dynamic onPrepared, dynamic onCompletion}) => MockVideoView();
    ima.PigeonOverrides.videoAdPlayer_new =
        ({
          required dynamic addCallback,
          required dynamic loadAd,
          required dynamic pauseAd,
          required dynamic playAd,
          required dynamic release,
          required dynamic removeCallback,
          required dynamic stopAd,
        }) => MockVideoAdPlayer();
    return AndroidAdDisplayContainer(
      AndroidAdDisplayContainerCreationParams(onContainerAdded: (_) {}),
    );
  }

  group('AndroidAdsManager', () {
    test('destroy', () {
      final mockAdsManager = MockAdsManager();
      final adsManager = AndroidAdsManager(mockAdsManager, testContainer());
      adsManager.destroy();

      verify(mockAdsManager.destroy());
    });

    test('init', () async {
      final mockAdsManager = MockAdsManager();

      final mockImaSdkFactory = MockImaSdkFactory();
      final mockAdsRenderingSettings = MockAdsRenderingSettings();
      when(
        mockImaSdkFactory.createAdsRenderingSettings(),
      ).thenAnswer((_) => Future<ima.AdsRenderingSettings>.value(mockAdsRenderingSettings));

      final adsManager = AndroidAdsManager(mockAdsManager, testContainer());

      ima.PigeonOverrides.imaSdkFactory_instance = mockImaSdkFactory;
      final settings = AndroidAdsRenderingSettings(
        const AndroidAdsRenderingSettingsCreationParams(
          bitrate: 1000,
          enablePreloading: false,
          loadVideoTimeout: Duration(seconds: 2),
          mimeTypes: <String>['value'],
          playAdsAfterTime: Duration(seconds: 5),
          uiElements: <AdUIElement>{AdUIElement.countdown},
          enableCustomTabs: true,
        ),
      );
      await adsManager.init(settings: settings);

      verifyInOrder(<Future<void>>[
        mockAdsRenderingSettings.setBitrateKbps(1000),
        mockAdsRenderingSettings.setEnablePreloading(false),
        mockAdsRenderingSettings.setLoadVideoTimeout(2000),
        mockAdsRenderingSettings.setMimeTypes(<String>['value']),
        mockAdsRenderingSettings.setPlayAdsAfterTime(5.0),
        mockAdsRenderingSettings.setUiElements(<ima.UiElement>[ima.UiElement.countdown]),
        mockAdsRenderingSettings.setEnableCustomTabs(true),
        mockAdsManager.init(mockAdsRenderingSettings),
      ]);
    });

    test('start', () {
      final mockAdsManager = MockAdsManager();
      final adsManager = AndroidAdsManager(mockAdsManager, testContainer());
      adsManager.start(AdsManagerStartParams());

      verify(mockAdsManager.start());
    });

    test('discardAdBreak', () {
      final mockAdsManager = MockAdsManager();
      final adsManager = AndroidAdsManager(mockAdsManager, testContainer());
      adsManager.discardAdBreak();

      verify(mockAdsManager.discardAdBreak());
    });

    test('pause', () {
      final mockAdsManager = MockAdsManager();
      final adsManager = AndroidAdsManager(mockAdsManager, testContainer());
      adsManager.pause();

      verify(mockAdsManager.pause());
    });

    test('setVolume reaches the media player through the display container', () async {
      late final Future<void> Function(ima.VideoView, ima.MediaPlayer) onPreparedCallback;

      ima.PigeonOverrides.frameLayout_new = () => MockFrameLayout();
      ima.PigeonOverrides.videoView_new =
          ({
            required dynamic onError,
            Future<void> Function(ima.VideoView, ima.MediaPlayer)? onPrepared,
            dynamic onCompletion,
          }) {
            onPreparedCallback = onPrepared!;
            return MockVideoView();
          };
      ima.PigeonOverrides.videoAdPlayer_new =
          ({
            required dynamic addCallback,
            required dynamic loadAd,
            required dynamic pauseAd,
            required dynamic playAd,
            required dynamic release,
            required dynamic removeCallback,
            required dynamic stopAd,
          }) => MockVideoAdPlayer();

      final container = AndroidAdDisplayContainer(
        AndroidAdDisplayContainerCreationParams(onContainerAdded: (_) {}),
      );
      final adsManager = AndroidAdsManager(MockAdsManager(), container);

      await adsManager.setVolume(0);

      final mediaPlayer = MockMediaPlayer();
      await onPreparedCallback(MockVideoView(), mediaPlayer);

      verify(mediaPlayer.setVolume(0, 0));
    });

    test('skip', () {
      final mockAdsManager = MockAdsManager();
      final adsManager = AndroidAdsManager(mockAdsManager, testContainer());
      adsManager.skip();

      verify(mockAdsManager.skip());
    });

    test('resume', () {
      final mockAdsManager = MockAdsManager();
      final adsManager = AndroidAdsManager(mockAdsManager, testContainer());
      adsManager.resume();

      verify(mockAdsManager.resume());
    });

    test('onAdEvent', () async {
      final mockAdsManager = MockAdsManager();

      late final void Function(ima.AdEventListener, ima.AdEvent) onAdEventCallback;

      ima.PigeonOverrides.adEventListener_new =
          ({required void Function(ima.AdEventListener, ima.AdEvent) onAdEvent}) {
            onAdEventCallback = onAdEvent;
            return MockAdEventListener();
          };
      ima.PigeonOverrides.adErrorListener_new = ({required dynamic onAdError}) {
        return MockAdErrorListener();
      };

      final adsManager = AndroidAdsManager(mockAdsManager, testContainer());
      await adsManager.setAdsManagerDelegate(
        AndroidAdsManagerDelegate(
          PlatformAdsManagerDelegateCreationParams(
            onAdEvent: expectAsync1((PlatformAdEvent event) {
              expect(event.type, AdEventType.allAdsCompleted);
              expect(event.adData, <String, String>{'hello': 'world'});
            }),
          ),
        ),
      );

      final mockAdEvent = MockAdEvent();
      when(mockAdEvent.type).thenReturn(ima.AdEventType.allAdsCompleted);
      when(mockAdEvent.adData).thenReturn(<String, String>{'hello': 'world'});
      onAdEventCallback(MockAdEventListener(), mockAdEvent);
    });

    test('onAdErrorEvent', () async {
      final mockAdsManager = MockAdsManager();

      late final void Function(ima.AdErrorListener, ima.AdErrorEvent) onAdErrorCallback;

      ima.PigeonOverrides.adEventListener_new = ({required dynamic onAdEvent}) {
        return MockAdEventListener();
      };
      ima.PigeonOverrides.adErrorListener_new =
          ({required void Function(ima.AdErrorListener, ima.AdErrorEvent) onAdError}) {
            onAdErrorCallback = onAdError;
            return MockAdErrorListener();
          };

      final adsManager = AndroidAdsManager(mockAdsManager, testContainer());
      await adsManager.setAdsManagerDelegate(
        AndroidAdsManagerDelegate(
          PlatformAdsManagerDelegateCreationParams(onAdErrorEvent: expectAsync1((_) {})),
        ),
      );

      final mockErrorEvent = MockAdErrorEvent();
      final mockError = MockAdError();
      when(mockError.errorType).thenReturn(ima.AdErrorType.load);
      when(mockError.errorCode).thenReturn(ima.AdErrorCode.adsRequestNetworkError);
      when(mockError.message).thenReturn('error message');
      when(mockErrorEvent.error).thenReturn(mockError);
      onAdErrorCallback(MockAdErrorListener(), mockErrorEvent);
    });

    test('adCuePoints', () {
      final mockAdsManager = MockAdsManager();

      final cuePoints = <double>[1.0];
      when(mockAdsManager.adCuePoints).thenReturn(cuePoints);
      final adsManager = AndroidAdsManager(mockAdsManager, testContainer());

      expect(adsManager.adCuePoints, <Duration>[const Duration(seconds: 1)]);
    });
  });
}
