import 'dart:convert';

import 'package:http/http.dart' as http;

const releaseRepository = 'lin1122lin/fqapp';

Future<({String version, Uri apk})?> checkReleaseUpdate(
  String installedVersion,
) async {
  final response = await http
      .get(
        Uri.https(
          'api.github.com',
          '/repos/$releaseRepository/releases/latest',
        ),
        headers: const {'Accept': 'application/vnd.github+json'},
      )
      .timeout(const Duration(seconds: 6));
  if (response.statusCode == 404) return null;
  if (response.statusCode != 200) {
    throw StateError('GitHub Releases HTTP ${response.statusCode}');
  }
  return newerRelease(jsonDecode(response.body), installedVersion);
}

({String version, Uri apk})? newerRelease(
  Object? release,
  String installedVersion,
) {
  if (release is! Map ||
      release['draft'] == true ||
      release['prerelease'] == true) {
    return null;
  }
  final pattern = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$');
  final tag = release['tag_name'];
  final latest = tag is String ? pattern.firstMatch(tag) : null;
  final current = pattern.firstMatch(installedVersion);
  if (latest == null || current == null) return null;
  var comparison = 0;
  for (var i = 1; i <= 3 && comparison == 0; i++) {
    comparison = int.parse(latest[i]!).compareTo(int.parse(current[i]!));
  }
  final assets = release['assets'];
  if (comparison <= 0 || assets is! List) return null;
  for (final asset in assets) {
    if (asset is! Map ||
        asset['name'] != 'app-release.apk' ||
        asset['state'] != 'uploaded') {
      continue;
    }
    final url = asset['browser_download_url'];
    final apk = url is String ? Uri.tryParse(url) : null;
    if (apk != null &&
        apk.scheme == 'https' &&
        apk.host == 'github.com' &&
        apk.userInfo.isEmpty &&
        !apk.hasPort &&
        apk.pathSegments.join('/') ==
            '$releaseRepository/releases/download/$tag/app-release.apk') {
      return (version: tag as String, apk: apk);
    }
  }
  return null;
}
