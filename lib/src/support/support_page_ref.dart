import 'package:flutter/foundation.dart' show immutable;

/// A typed pointer to the thing the customer is looking at, sent with a support
/// message so they do not have to describe it.
///
/// A reference is never free text: the host app decides which [kind]s exist
/// (`monitor`, `invoice`, ...) and what an [id] means for each, and the backend
/// accepts only the kinds it is configured with. Neither value is shown to the
/// customer. A host registers them through `MagicStarter.usePageContext`.
@immutable
class MagicStarterSupportPageRef {
  /// The host's name for what is referenced, such as `monitor`.
  final String kind;

  /// The identifier of the referenced thing within [kind], as a string.
  final String id;

  const MagicStarterSupportPageRef({required this.kind, required this.id});

  /// The shape of one `page_context` entry on the wire.
  Map<String, String> toMap() => <String, String>{'kind': kind, 'id': id};

  @override
  bool operator ==(Object other) =>
      other is MagicStarterSupportPageRef &&
      other.kind == kind &&
      other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}
