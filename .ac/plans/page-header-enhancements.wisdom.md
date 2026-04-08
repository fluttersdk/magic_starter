# Wisdom: PageHeader Enhancements

- **Wave 1**: Tests can reference params that don't exist yet — compile errors are the expected "red" phase in TDD for new API additions
- **Wave 2**: `if (x != null) x!` spread inside `children: []` is the correct pattern for optional widget slots — no SizedBox.shrink(), no ternary WDiv wrapper
- **Wave 2**: Outer WDiv className ternary inlined directly in the parameter — no computed variable extraction needed for simple 2-branch conditionals
- **Review**: When plan specifies `flex-shrink-0` on a widget slot, verify it actually appears in the implementation — easy to miss CSS utility classes in Wind UI
