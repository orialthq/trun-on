import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/domain/models.dart';
import 'package:ori_beauty/domain/portable_tip_package.dart';
import 'package:ori_beauty/features/sharing/received_tip_sheet.dart';

void main() {
  testWidgets('received tip sheet remains usable at 150 percent text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    ReceivedTipDecision? decision;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  decision = await showReceivedTipSheet(context, _tip());
                },
                child: const Text('팁 열기'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('팁 열기'));
    await tester.pumpAndSettle();

    expect(find.text('받은 팁'), findsOneWidget);
    expect(find.text('주말에 함께 가고 싶은 성수 맛집'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Theme &&
            widget.data.brightness == Brightness.light &&
            widget.data.scaffoldBackgroundColor == AppTheme.planCanvas,
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);

    final saveButton = find.text('정리함에 저장');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(decision, ReceivedTipDecision.save);
    expect(tester.takeException(), isNull);
  });
}

PortableTipPackage _tip() {
  return PortableTipPackage.create(
    packageId: 'received-tip-scale-test',
    exportedAt: DateTime.utc(2026, 8, 18),
    title: '주말에 함께 가고 싶은 성수 맛집',
    summary: '친구가 직접 골라 보낸 장소와 방문 전에 알아둘 정보를 차분히 확인해요.',
    category: ContentFolder.restaurantCafe,
    subcategory: '한식',
    facts: [
      PortableTipFact(label: '대표 메뉴', value: '철판쭈꾸미와 볶음밥'),
      PortableTipFact(label: '영업시간', value: '매일 오전 11시부터 오후 10시까지'),
      PortableTipFact(label: '예약', value: '주말에는 미리 예약하는 편이 좋아요'),
    ],
    notes: const ['마지막 볶음밥은 꼭 먹기', '인근 공영주차장 이용하기'],
    place: PortableTipPlace(name: '성수 맛집', address: '서울 성동구 서울숲길 24'),
    source: PortableTipSource(label: '원문', url: 'https://example.com/tip'),
    message: '이번 주말에 같이 가볼래?',
  );
}
