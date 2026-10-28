import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// New random identifier for habits, checklist items, notes and categories.
String newId() => _uuid.v4();
