import 'package:flutter_test/flutter_test.dart';
import 'package:fqapp/services/release_update.dart';

void main() {
  test('only a newer stable APK from the fork is offered', () {
    const url =
        'https://github.com/lin1122lin/fqapp/releases/download/v1.0.210/app-release.apk';
    final release = {
      'tag_name': 'v1.0.210',
      'assets': [
        {
          'name': 'app-release.apk',
          'state': 'uploaded',
          'browser_download_url': url,
        },
      ],
    };
    expect(newerRelease(release, '1.0.99')?.apk, Uri.parse(url));
    expect(newerRelease(release, '1.0.210'), isNull);
    expect(newerRelease({...release, 'prerelease': true}, '1.0.99'), isNull);
    expect(
      newerRelease({
        ...release,
        'assets': [
          {
            'name': 'app-release.apk',
            'state': 'uploaded',
            'browser_download_url': url.replaceFirst('lin1122lin', 'ch6vip'),
          },
        ],
      }, '1.0.99'),
      isNull,
    );
  });
}
