/// Immutable local snapshot of a task/subtask event. Kept separately from the
/// mutable task row so historical analytics survives edits and deletion.
class TaskActivity {
  const TaskActivity({
    required this.id,
    required this.taskId,
    required this.title,
    required this.dueDate,
    required this.priority,
    required this.activityType,
    required this.occurredAt,
    this.parentId,
    this.category = '',
    this.createdAt,
    this.reminderAt,
    this.isPaused = false,
  });

  final String id;
  final String taskId;
  final String title;
  final DateTime dueDate;
  final int priority;
  final String activityType; // created | updated | completed | reopened
  final DateTime occurredAt;
  final String? parentId;
  final String category;
  final DateTime? createdAt;
  final DateTime? reminderAt;
  final bool isPaused;

  bool get isCompletion => activityType == 'completed';
  bool get isSubtask => parentId != null;

  factory TaskActivity.fromRow(Map<String, Object?> row) => TaskActivity(
        id: row['id'] as String,
        taskId: row['task_id'] as String,
        title: row['title'] as String? ?? 'Task',
        dueDate: DateTime.tryParse(row['due_date'] as String? ?? '') ?? DateTime.now(),
        priority: row['priority'] as int? ?? 2,
        activityType: row['activity_type'] as String? ?? 'completed',
        occurredAt: DateTime.tryParse(row['occurred_at'] as String? ?? '') ?? DateTime.now(),
        parentId: row['parent_id'] as String?,
        category: row['category'] as String? ?? '',
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
        reminderAt: DateTime.tryParse(row['reminder_at'] as String? ?? ''),
        isPaused: (row['is_paused'] as int? ?? 0) == 1,
      );
}
