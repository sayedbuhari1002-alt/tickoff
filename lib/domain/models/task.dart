import 'package:flutter/foundation.dart';

@immutable
class TaskItem {
  const TaskItem({
    required this.id, required this.title, required this.createdAt,
    required this.updatedAt, required this.dueDate,
    this.description = '', this.priority = 2, this.category = '',
    this.colorValue = 0xFFFFC62B, this.iconCodePoint = 0xe163,
    this.isCompleted = false, this.isPaused = false, this.parentId,
    this.sortOrder = 0, this.reminderAt, this.notes = '', this.photoPaths = const [],
    this.audioPaths = const [], this.repeatRule = 'none', this.completedAt,
  });
  final String id, title, description, category, notes, repeatRule;
  final DateTime createdAt, updatedAt, dueDate;
  final int priority, colorValue, iconCodePoint, sortOrder;
  final bool isCompleted, isPaused;
  final String? parentId;
  final DateTime? reminderAt;
  final DateTime? completedAt;
  final List<String> photoPaths, audioPaths;

  bool get isSubtask => parentId != null;
  bool isOverdue(DateTime now) {
    if (isCompleted || isPaused) return false;
    final bool hasExplicitTime = dueDate.hour != 0 || dueDate.minute != 0;
    if (hasExplicitTime) return dueDate.isBefore(now);
    return DateTime(dueDate.year, dueDate.month, dueDate.day).isBefore(DateTime(now.year, now.month, now.day));
  }
  TaskItem copyWith({String? title, String? description, String? category, int? priority, int? colorValue, int? iconCodePoint, bool? isCompleted, bool? isPaused, DateTime? dueDate, DateTime? updatedAt, DateTime? reminderAt, bool clearReminder = false, String? parentId, bool clearParent = false, int? sortOrder, String? notes, List<String>? photoPaths, List<String>? audioPaths, String? repeatRule, DateTime? completedAt, bool clearCompletedAt = false}) => TaskItem(
    id:id,title:title??this.title,description:description??this.description,category:category??this.category,
    createdAt:createdAt,updatedAt:updatedAt??DateTime.now(),dueDate:dueDate??this.dueDate,priority:priority??this.priority,
    colorValue:colorValue??this.colorValue,iconCodePoint:iconCodePoint??this.iconCodePoint,isCompleted:isCompleted??this.isCompleted,
    isPaused:isPaused??this.isPaused,parentId:clearParent?null:(parentId??this.parentId),sortOrder:sortOrder??this.sortOrder,
    reminderAt:clearReminder?null:(reminderAt??this.reminderAt),completedAt:clearCompletedAt?null:(completedAt??this.completedAt),notes:notes??this.notes,photoPaths:photoPaths??this.photoPaths,audioPaths:audioPaths??this.audioPaths,repeatRule:repeatRule??this.repeatRule);
  Map<String,Object?> toRow()=>{'id':id,'title':title,'description':description,'created_at':createdAt.toIso8601String(),'updated_at':updatedAt.toIso8601String(),'due_date':dueDate.toIso8601String(),'priority':priority,'category':category,'color_value':colorValue,'icon_code_point':iconCodePoint,'is_completed':isCompleted?1:0,'completed_at':completedAt?.toIso8601String(),'is_paused':isPaused?1:0,'parent_id':parentId,'sort_order':sortOrder,'reminder_at':reminderAt?.toIso8601String(),'notes':notes,'photo_paths':photoPaths.join('\n'),'audio_paths':audioPaths.join('\n'),'repeat_rule':repeatRule};
  factory TaskItem.fromRow(Map<String,Object?> r)=>TaskItem(id:r['id'] as String,title:r['title'] as String,description:(r['description'] as String?)??'',createdAt:DateTime.tryParse(r['created_at'] as String? ?? '')??DateTime.now(),updatedAt:DateTime.tryParse(r['updated_at'] as String? ?? '')??DateTime.now(),dueDate:DateTime.tryParse(r['due_date'] as String? ?? '')??DateTime.now(),priority:r['priority'] as int? ?? 2,category:r['category'] as String? ?? '',colorValue:r['color_value'] as int? ?? 0xFFFFC62B,iconCodePoint:r['icon_code_point'] as int? ?? 0xe163,isCompleted:(r['is_completed'] as int? ?? 0)==1,completedAt:DateTime.tryParse(r['completed_at'] as String? ?? ''),isPaused:(r['is_paused'] as int? ?? 0)==1,parentId:r['parent_id'] as String?,sortOrder:r['sort_order'] as int? ?? 0,reminderAt:DateTime.tryParse(r['reminder_at'] as String? ?? ''),notes:r['notes'] as String? ?? '',photoPaths:((r['photo_paths'] as String?)??'').split('\n').where((s)=>s.isNotEmpty).toList(),audioPaths:((r['audio_paths'] as String?)??'').split('\n').where((s)=>s.isNotEmpty).toList(),repeatRule:r['repeat_rule'] as String? ?? 'none');
}
