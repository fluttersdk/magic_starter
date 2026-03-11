---
path: "lib/src/http/controllers/**/*.dart"
---

# HTTP Controllers

- Error handling: `handleApiError(response, fallback: trans('key'))` — never raw exception messages
- Try/catch wraps ALL async operations with structured logging:
  ```dart
  try { ... } catch (e, stackTrace) {
    Log.error('[ClassName.method] $e\n$stackTrace');
    setError(trans('...'));
  }
  ```
- API calls: `Http.post()`, `Http.put()`, `Http.delete()`, `Http.upload()` — no raw Dio
- Widget rendering: `controller.renderState((_) => _buildForm())` with optional `onEmpty:` and `onError:`
- Payload construction: build `Map<String, dynamic>` with conditional entries via spread:
  ```dart
  final payload = {
    'name': form['name'],
    if (form['email']?.isNotEmpty == true) 'email': form['email'],
  };
  ```
- Identity mode helper: `_applyIdentityToPayload()` handles email/phone/both logic centrally
- Auth state sync: call `Auth.restore()` after login, register, or profile update to reload user model
- Navigation: use `navigateTo(path)` from `NavigatesRoutes` mixin — never `context.go()` directly
- Suppress notifications pattern: `_suppressNotifications = true` to prevent full-page rebuilds during form-level loading, restore in finally block
- `ValueNotifier<T>` for fine-grained reactive state beyond MagicStateMixin:
  ```dart
  final matrixNotifier = ValueNotifier<Map<String, dynamic>>({});
  ```
- `withoutNotifying()` helper wraps async action with `_suppressNotifications = true` / finally restore
- Recursive normalization: `_normalizeMap()` for backend responses with mixed-case or dynamic keys
- OTP two-step flow: `sendOtp()` sets state for code input → `verifyOtp()` completes authentication
- Newsletter controller: simple subscribe/unsubscribe — no navigation, view-only state changes
- Two-level response extraction — always check BOTH top-level and nested `data`:
  ```dart
  final data = response.data?['data'] as Map<String, dynamic>?;
  final token = data?['token'];
  ```
- Async methods return `bool` or `Map?` (not void) so callers can branch without reading controller state
- Laravel method spoofing: use `{'_method': 'DELETE'}` in `Http.post()` for deletion confirmations
