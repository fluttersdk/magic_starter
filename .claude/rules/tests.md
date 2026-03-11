---
path: "test/**/*_test.dart"
---

# Testing Conventions

- Mock classes: `MockNetworkDriver implements NetworkDriver`, `MockGuard implements Guard`
- MockNetworkDriver tracks: `lastMethod`, `lastUrl`, `lastData`, `lastHeaders`
- Setup mock responses: `mockDriver.mockResponse(statusCode: 200, data: {...})`
- Standard setUp block:
  ```dart
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('network', () => MockNetworkDriver());
    Magic.singleton('auth', () => MockGuard());
    // bind config, register guards as needed
  });
  ```
- Standard tearDown: dispose controller, `Auth.manager.forgetGuards()`, silent-catch `Notify.stopPolling()`
- Group tests by controller/class: `group('ControllerName', () { ... })`
- Payload verification: `expect(mockDriver.lastData['field'], expectedValue)`
- State verification: `expect(controller.isSuccess, isTrue)`, `expect(controller.hasErrors, isFalse)`
- URL verification: `expect(mockDriver.lastUrl, contains('/api/path'))`
- Method verification: `expect(mockDriver.lastMethod, 'POST')`
- Always reset Magic/MagicApp before each test — auth state persists if not reset
- Config binding for feature flags: `Config.set('magic_starter.features.x', true)` in setUp
- ValueNotifier disposal: controllers with `ValueNotifier` fields must have `notifier.dispose()` in tearDown
- Response queue: `mockDriver.mockResponse()` can be called multiple times for multi-request flows (e.g., OTP send → verify)
- Route path assertions: verify navigation intent via `MagicStarterConfig.<module>Path()` — no actual navigation in tests
