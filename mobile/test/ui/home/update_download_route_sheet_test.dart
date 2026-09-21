import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms_sync_mobile/services/app_update_service.dart';
import 'package:sms_sync_mobile/ui/home/update_download_route_sheet.dart';

void main() {
  testWidgets('UpdateDownloadRouteSheet renders routes and returns selection', (
    tester,
  ) async {
    AppDownloadOption? selectedOption;
    const options = <AppDownloadOption>[
      AppDownloadOption(
        url: 'https://download.example.com/sms-sync-mobile.apk',
        label: '默认安装包',
        host: 'download.example.com',
      ),
      AppDownloadOption(
        url: 'https://a.example.com/sms-sync-mobile.apk',
        label: 'Line A',
        host: 'a.example.com',
      ),
      AppDownloadOption(
        url: 'https://b.example.com/sms-sync-mobile.apk',
        label: 'b.example.com',
        host: 'b.example.com',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdateDownloadRouteSheet(
            options: options,
            onSelected: (option) {
              selectedOption = option;
            },
          ),
        ),
      ),
    );

    expect(find.text('选择下载路线'), findsOneWidget);
    expect(find.textContaining('默认安装包'), findsWidgets);
    expect(find.textContaining('镜像'), findsOneWidget);
    expect(find.text('Line A'), findsOneWidget);
    expect(find.text('https://b.example.com/sms-sync-mobile.apk'), findsOneWidget);

    await tester.tap(find.text('Line A'));
    await tester.pump();

    expect(selectedOption, options[1]);
  });
}
