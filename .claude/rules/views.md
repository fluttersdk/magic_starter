---
path: "lib/src/ui/views/**/*.dart"
---

# UI Views

- Class hierarchy: `extends MagicStatefulView<ControllerType>` with state `MagicStatefulViewState<ControllerType, ViewType>`
- Form state: `late final form = MagicFormData({...}, controller: controller)` with empty string defaults
- Lifecycle hooks: `onInit()` for setup (clear errors, set empty state), `onClose()` for disposal
- Build pattern with state handling:
  ```dart
  controller.renderState(
    (_) => _buildForm(),
    onEmpty: _buildForm(),
    onError: (msg) => _buildForm(errorMessage: msg),
  )
  ```
- Extract state checks at method top: `final isLoading = controller.isLoading;`
- Form submission flow: validate form -> call controller method -> controller handles navigation
- Wind UI exclusively — no Material widgets:
  - Layout: `WDiv(className: 'flex flex-col gap-4 p-6')`
  - Text: `WText('label', className: 'text-sm font-medium text-gray-700 dark:text-gray-300')`
  - Input: `WFormInput(form: form, name: 'email')`
  - Button: `WButton(onPressed: submit, className: '...')`
- Multi-line className with triple quotes for readability:
  ```dart
  className: '''
    rounded-2xl bg-white dark:bg-gray-800
    border border-gray-200 dark:border-gray-700
  '''
  ```
- Dark mode: always pair light/dark classes: `text-gray-900 dark:text-white`
- Conditional rendering via spreads: `if (condition) ...[widget1, widget2]`
- Password toggle: local `setState(() => _obscurePassword = !_obscurePassword)` — not controller state
- `ValueListenableBuilder` for controller's `ValueNotifier` state (matrixNotifier, team members):
  ```dart
  ValueListenableBuilder<Map<String, dynamic>>(
    valueListenable: controller.matrixNotifier,
    builder: (_, matrix, __) => _buildGrid(matrix),
  )
  ```
- Section-level loading: multiple local `ValueNotifier<bool>` fields (_photoLoading, _emailVerificationLoading) for independent section spinners
- Multi-form: complex views hold multiple `MagicFormData` instances — field names MUST NOT collide across forms
- Type-safe form extraction: `form.value<bool>('remember_me')` — not `form.get()` for non-string fields
- Query param extraction in view (before calling controller): `MagicRouter.instance.queryParameter('token') ?? ''`
- Feature-gated spreads at build time: `if (MagicStarterConfig.hasGuestAuthFeatures()) ...[...]`
- Zero business logic in views — all async/state decisions live in controllers
