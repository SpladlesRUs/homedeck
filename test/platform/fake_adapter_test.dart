import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_outcome.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:path/path.dart' as p;

import '../helpers/fake_platform_adapter.dart';
import '../helpers/test_harness.dart';

void main() {
  test('fake adapter is scriptable and discover stays empty by default', () async {
    final adapter = FakePlatformAdapter(
      validation: LaunchFailure.missingFile(targetValue: 'gone.exe'),
      pick: PickedLaunch(
        displayName: 'Picked',
        target: windowsTarget(p.join('picked', 'App.exe')),
      ),
    );

    expect(await adapter.discover(), isEmpty);
    expect(adapter.platform, AppPlatform.windows);

    final picked = await adapter.pickLaunchTarget();
    expect(picked?.displayName, 'Picked');

    final outcome = await adapter.launch(picked!.target);
    expect(outcome, isA<LaunchFailure>());
    expect((outcome as LaunchFailure).kind, LaunchFailureKind.missingFile);
    expect(adapter.launchCount, 1);
    expect(adapter.validateCount, 1);
  });

  test('fake adapter can report a successful launch', () async {
    final adapter = FakePlatformAdapter();
    final target = windowsTarget(p.join('apps', 'ok.exe'));
    expect(await adapter.validateTarget(target), isNull);
    expect(await adapter.launch(target), isA<LaunchSuccess>());
  });
}
