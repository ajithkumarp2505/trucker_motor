import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide Transition;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:trucker_motor/core/theme/app_theme.dart';
import 'package:trucker_motor/features/tasks/bloc/task_bloc.dart';
import 'package:trucker_motor/features/tasks/bloc/task_event.dart';
import 'package:trucker_motor/features/tasks/models/task_model.dart';

class AddEditTaskScreen extends StatefulWidget {
  const AddEditTaskScreen({super.key});

  @override
  State<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends State<AddEditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  String _priority = 'Medium';
  String _status = 'Pending';

  TaskModel? _existingTask;
  bool get _isEditMode => _existingTask != null;

  final List<String> _priorities = ['Low', 'Medium', 'High'];
  final List<String> _statuses = ['Pending', 'In Progress', 'Done'];

  @override
  void initState() {
    super.initState();

    if (Get.arguments is TaskModel) {
      _existingTask = Get.arguments as TaskModel;
      _titleController.text = _existingTask!.title;
      _descriptionController.text = _existingTask!.description;
      _dueDate = _existingTask!.dueDate;
      _priority = _existingTask!.priority;
      _status = _existingTask!.status;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Get.back(),
        ),
        title: Text(_isEditMode ? 'Edit Task' : 'New Task'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Title ─────────────────────────────────────
              _buildSectionLabel('Title *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'Enter task title',
                  prefixIcon: Icon(
                    Icons.title_rounded,
                    color: AppTheme.primaryColor,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ─── Description ───────────────────────────────
              _buildSectionLabel('Description'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'Add a description...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),

              // ─── Due Date ──────────────────────────────────
              _buildSectionLabel('Due Date *'),
              const SizedBox(height: 8),
              _buildDatePicker(context),
              const SizedBox(height: 20),

              // ─── Priority ──────────────────────────────────
              _buildSectionLabel('Priority'),
              const SizedBox(height: 8),
              _buildPrioritySelector(),
              const SizedBox(height: 20),

              // ─── Status (only in edit mode) ────────────────
              if (_isEditMode) ...[
                _buildSectionLabel('Status'),
                const SizedBox(height: 8),
                _buildStatusSelector(),
                const SizedBox(height: 20),
              ],

              const SizedBox(height: 12),

              // ─── Submit Button ─────────────────────────────
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isEditMode ? Icons.save_rounded : Icons.add_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isEditMode ? 'Save Changes' : 'Create Task',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppTheme.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return InkWell(
      onTap: () => _selectDate(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              DateFormat('EEEE, MMMM d, y').format(_dueDate),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTheme.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return Row(
      children: _priorities.map((priority) {
        final isSelected = _priority == priority;
        final color = AppTheme.getPriorityColor(priority);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: priority == 'Low' ? 0 : 4,
              right: priority == 'High' ? 0 : 4,
            ),
            child: InkWell(
              onTap: () => setState(() => _priority = priority),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? color.withValues(alpha: 0.5)
                        : AppTheme.dividerColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      AppTheme.getPriorityIcon(priority),
                      color: isSelected ? color : AppTheme.textMuted,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      priority,
                      style: TextStyle(
                        color: isSelected ? color : AppTheme.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusSelector() {
    return Row(
      children: _statuses.map((status) {
        final isSelected = _status == status;
        final color = AppTheme.getStatusColor(status);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: status == 'Pending' ? 0 : 4,
              right: status == 'Done' ? 0 : 4,
            ),
            child: InkWell(
              onTap: () => setState(() => _status = status),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? color.withValues(alpha: 0.5)
                        : AppTheme.dividerColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      AppTheme.getStatusIcon(status),
                      color: isSelected ? color : AppTheme.textMuted,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: TextStyle(
                        color: isSelected ? color : AppTheme.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: AppTheme.surfaceColor,
              onSurface: AppTheme.textPrimary,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppTheme.surfaceColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final bloc = context.read<TaskBloc>();

    if (_isEditMode) {
      final updated = _existingTask!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
        status: _status,
      );
      bloc.add(UpdateTask(task: updated));
    } else {
      final newTask = TaskModel(
        id: '', // Will be assigned by repository
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
        status: _status,
        createdAt: DateTime.now(),
      );
      bloc.add(AddTask(task: newTask));
    }

    Get.back();

    Get.snackbar(
      _isEditMode ? 'Task Updated' : 'Task Created',
      _isEditMode
          ? 'Changes saved successfully'
          : '${_titleController.text.trim()} has been created',
      backgroundColor: AppTheme.successColor.withValues(alpha: 0.9),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
  }
}
