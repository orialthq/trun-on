import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/data/content_share_service.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  test('card share copy includes three tappable map links for a place', () {
    final text = buildCardShareText(
      placeName: '동묘집',
      placeAddress: '서울 종로구 종로52길 43-9',
    )!;

    expect(text, startsWith('📍 동묘집\n'));
    expect(text, contains('네이버 https://map.naver.com/'));
    expect(text, contains('카카오 https://map.kakao.com/'));
    expect(text, contains('구글 https://maps.google.com/'));
    expect(text, isNot(contains('동묘집 철판쭈꾸미')));
    expect(text, isNot(contains('%EC')));
    expect(text.split('\n'), hasLength(4));
  });

  test('place-free card stays image only', () {
    expect(buildCardShareText(), isNull);
  });

  group('map-link follow-up', () {
    const mapText = '네이버 지도: https://map.naver.com/example';

    test('is offered after every successful place-card share', () {
      expect(
        shouldOfferMapLinkFollowUp(
          result: const ShareResult(
            'com.kakao.talk/.activity.chatroom.ChatRoomActivity',
            ShareResultStatus.success,
          ),
          mapShareText: mapText,
        ),
        isTrue,
      );
      expect(
        shouldOfferMapLinkFollowUp(
          result: const ShareResult(
            'com.google.android.apps.messaging/.ShareActivity',
            ShareResultStatus.success,
          ),
          mapShareText: mapText,
        ),
        isTrue,
      );
    });

    test('is skipped for cancellation and place-free cards', () {
      expect(
        shouldOfferMapLinkFollowUp(
          result: const ShareResult(
            'com.kakao.talk/.activity.chatroom.ChatRoomActivity',
            ShareResultStatus.dismissed,
          ),
          mapShareText: mapText,
        ),
        isFalse,
      );
      expect(
        shouldOfferMapLinkFollowUp(
          result: const ShareResult(
            'com.kakao.talk/.activity.chatroom.ChatRoomActivity',
            ShareResultStatus.success,
          ),
          mapShareText: null,
        ),
        isFalse,
      );
    });

    test('works when direct share does not identify the target component', () {
      expect(
        shouldOfferMapLinkFollowUp(
          result: const ShareResult('', ShareResultStatus.success),
          mapShareText: mapText,
        ),
        isTrue,
      );
    });
  });
}
