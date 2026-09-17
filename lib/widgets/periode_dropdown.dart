import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/periode_provider.dart';
import '../theme/app_theme.dart';

/// Pemilih periode berbentuk pil untuk diletakkan di bawah header
/// gradien. Tersinkron global lewat [PeriodeProvider].
class PeriodeSelector extends StatelessWidget {
  const PeriodeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PeriodeProvider>(
      builder: (context, pp, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_note_rounded,
                  size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              if (pp.items.isEmpty)
                Text(
                  'Periode ${pp.value ?? '-'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: pp.value,
                    dropdownColor:
                        context.isDark ? const Color(0xFF1B2140) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70, size: 19),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.isDark ? Colors.white : AppColors.indigo900,
                    ),
                    items: pp.items
                        .map((e) => DropdownMenuItem<String>(
                              value: e.value,
                              child: Text(e.label,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) pp.set(v);
                    },
                  ),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: pp.forceReload,
                icon: const Icon(Icons.refresh_rounded,
                    size: 17, color: Colors.white70),
                tooltip: 'Muat ulang periode',
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pemilih pil generik (dipakai KHS & Kalender yang punya daftar sendiri).
class PillDropdown extends StatelessWidget {
  const PillDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint = 'Pilih',
  });

  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month_rounded,
              size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(hint,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              dropdownColor:
                  context.isDark ? const Color(0xFF1B2140) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white70, size: 19),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.isDark ? Colors.white : AppColors.indigo900,
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}
