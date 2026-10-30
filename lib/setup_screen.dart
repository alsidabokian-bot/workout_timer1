import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_background.dart';
import 'format.dart';
import 'settings_screen.dart';
import 'store.dart';
import 'theme.dart';
import 'workout_screen.dart';

/// شاشة ضبط وقت التمرين والراحة وعدد الجولات.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  static const _step = 5; // خطوة زر (+) و(−) بالثواني

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return BackgroundScaffold(
      appBar: AppBar(
        title: const Text('عداد التمرين'),
        actions: [
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'إعادة الضبط',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: store.resetTimes,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _SummaryCard(store: store),
            const SizedBox(height: 16),
            _SettingCard(
              icon: Icons.fitness_center_rounded,
              title: 'وقت التمرين',
              color: AppTheme.primary,
              valueText: formatTime(store.workSeconds),
              hint: 'اضغط على الرقم لكتابة قيمة',
              onMinus: store.workSeconds > AppStore.minWork
                  ? () => store.setWorkSeconds(store.workSeconds - _step)
                  : null,
              onPlus: store.workSeconds < AppStore.maxWork
                  ? () => store.setWorkSeconds(store.workSeconds + _step)
                  : null,
              onEdit: () => _editNumber(
                context,
                title: 'وقت التمرين',
                label: 'بالثواني',
                current: store.workSeconds,
                min: AppStore.minWork,
                max: AppStore.maxWork,
                onSave: store.setWorkSeconds,
              ),
              presets: const [20, 30, 45, 60],
              presetLabel: _secLabel,
              selected: store.workSeconds,
              onPreset: store.setWorkSeconds,
            ),
            const SizedBox(height: 16),
            _SettingCard(
              icon: Icons.self_improvement_rounded,
              title: 'وقت الراحة',
              color: AppTheme.secondary,
              valueText:
                  store.restSeconds == 0 ? 'بدون' : formatTime(store.restSeconds),
              hint: 'اضغط على الرقم لكتابة قيمة',
              onMinus: store.restSeconds > AppStore.minRest
                  ? () => store.setRestSeconds(store.restSeconds - _step)
                  : null,
              onPlus: store.restSeconds < AppStore.maxRest
                  ? () => store.setRestSeconds(store.restSeconds + _step)
                  : null,
              onEdit: () => _editNumber(
                context,
                title: 'وقت الراحة',
                label: 'بالثواني (0 = بدون راحة)',
                current: store.restSeconds,
                min: AppStore.minRest,
                max: AppStore.maxRest,
                onSave: store.setRestSeconds,
              ),
              presets: const [0, 10, 15, 30, 60],
              presetLabel: (v) => v == 0 ? 'بدون' : _secLabel(v),
              selected: store.restSeconds,
              onPreset: store.setRestSeconds,
            ),
            const SizedBox(height: 16),
            _SettingCard(
              icon: Icons.repeat_rounded,
              title: 'عدد الجولات',
              color: const Color(0xFF2EC4A6),
              valueText: '${store.rounds}',
              hint: 'اضغط على الرقم لكتابة قيمة',
              onMinus: store.rounds > AppStore.minRounds
                  ? () => store.setRounds(store.rounds - 1)
                  : null,
              onPlus: store.rounds < AppStore.maxRounds
                  ? () => store.setRounds(store.rounds + 1)
                  : null,
              onEdit: () => _editNumber(
                context,
                title: 'عدد الجولات',
                label: 'عدد الجولات',
                current: store.rounds,
                min: AppStore.minRounds,
                max: AppStore.maxRounds,
                onSave: store.setRounds,
              ),
              presets: const [3, 5, 8, 10, 12],
              presetLabel: (v) => '$v',
              selected: store.rounds,
              onPreset: store.setRounds,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const WorkoutScreen()),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: const Text('ابدأ التمرين'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  static String _secLabel(int v) => v < 60 ? '$v ث' : formatTime(v);

  /// نافذة لكتابة قيمة دقيقة بدل الضغط المتكرر على (+).
  static Future<void> _editNumber(
    BuildContext context, {
    required String title,
    required String label,
    required int current,
    required int min,
    required int max,
    required ValueChanged<int> onSave,
  }) async {
    final controller = TextEditingController(text: '$current');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: label,
            helperText: 'من $min إلى $max',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result != null) onSave(result); // المتجر يقصّ القيمة داخل الحدود
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final rest = store.restSeconds == 0
        ? 'بدون راحة'
        : 'راحة ${formatTime(store.restSeconds)}';
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Text(
            'المدة الكلية',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatTime(store.totalSeconds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${store.rounds} جولات  •  تمرين ${formatTime(store.workSeconds)}  •  $rest',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.valueText,
    required this.hint,
    required this.onMinus,
    required this.onPlus,
    required this.onEdit,
    required this.presets,
    required this.presetLabel,
    required this.selected,
    required this.onPreset,
  });

  final IconData icon;
  final String title;
  final Color color;
  final String valueText;
  final String hint;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final VoidCallback onEdit;
  final List<int> presets;
  final String Function(int) presetLabel;
  final int selected;
  final ValueChanged<int> onPreset;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: onMinus,
                  icon: const Icon(Icons.remove_rounded),
                ),
                Expanded(
                  child: InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          Text(
                            valueText,
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: color,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(hint, style: TextStyle(fontSize: 12, color: muted)),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: onPlus,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in presets)
                  ChoiceChip(
                    label: Text(presetLabel(v)),
                    selected: v == selected,
                    onSelected: (_) => onPreset(v),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
