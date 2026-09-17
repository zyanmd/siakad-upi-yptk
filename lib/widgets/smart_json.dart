import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/smart.dart';
import 'common.dart';

/// Renderer JSON serbaguna untuk respons scraper yang bentuknya
/// dinamis: map -> baris key-value, list -> deretan kartu bernomor,
/// primitif -> teks. Key berisi token otomatis disembunyikan,
/// link http bisa ditap, tekan lama untuk salin.
class SmartJson extends StatelessWidget {
  const SmartJson({
    super.key,
    required this.data,
    this.excludeKeys = const [],
    this.depth = 0,
  });

  final dynamic data;
  final List<String> excludeKeys;
  final int depth;

  static const _hiddenSubstrings = [
    'token',
    'session',
    'password',
    'scraper',
    'html',
  ];

  bool _hidden(String key) {
    final lk = key.toLowerCase();
    if (excludeKeys.contains(lk)) return true;
    return _hiddenSubstrings.any((h) => lk.contains(h));
  }

  @override
  Widget build(BuildContext context) {
    return _render(context, data, depth);
  }

  Widget _render(BuildContext context, dynamic v, int d) {
    if (v == null) {
      return Text('-', style: TextStyle(color: context.textMuted, fontSize: 13));
    }
    if (v is Map) {
      return _renderMap(context, v, d);
    }
    if (v is List) {
      return _renderList(context, v, d);
    }
    return _renderPrimitive(context, v);
  }

  // ------------------------------------------------------------- map

  Widget _renderMap(BuildContext context, Map v, int d) {
    final entries = v.entries
        .where((e) => !_hidden(e.key.toString()))
        .toList(growable: false);
    if (entries.isEmpty) {
      return Text('-',
          style: TextStyle(color: context.textMuted, fontSize: 13));
    }

    final primitives = <MapEntry>[];
    final nested = <MapEntry>[];
    for (final e in entries) {
      final val = e.value;
      final isMapList = val is List &&
          val.isNotEmpty &&
          val.every((x) => x is Map);
      if (val is Map || isMapList) {
        nested.add(e);
      } else if (val is List && val.isNotEmpty) {
        // list primitif -> gabung jadi satu baris
        primitives.add(MapEntry(e.key, val.map((x) => x.toString()).join(', ')));
      } else if (val is List) {
        continue; // list kosong: lewati
      } else {
        primitives.add(e);
      }
    }

    final kids = <Widget>[];
    if (primitives.isNotEmpty) {
      kids.add(
        Container(
          decoration: BoxDecoration(
            color: context.softFill,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: Column(
            children: primitives
                .map((e) => _kvRow(context, e.key.toString(), e.value))
                .toList(),
          ),
        ),
      );
      kids.add(const SizedBox(height: 10));
    }

    for (var i = 0; i < nested.length; i++) {
      final e = nested[i];
      kids.add(
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: context.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Theme(
            data: Theme.of(context)
                .copyWith(dividerColor: Colors.transparent, splashColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding:
                  const EdgeInsets.fromLTRB(12, 0, 12, 12),
              initiallyExpanded: d < 1 && nested.length <= 4,
              iconColor: context.textMuted,
              collapsedIconColor: context.textMuted,
              title: Text(
                labelify(e.key.toString()),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              children: [
                SmartJson(data: e.value, depth: d + 1),
              ],
            ),
          ),
        ),
      );
      if (i != nested.length - 1) kids.add(const SizedBox(height: 8));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: kids.isEmpty ? [const SizedBox.shrink()] : kids,
    );
  }

  Widget _kvRow(BuildContext context, String key, dynamic value) {
    final isUrl = value is String && value.startsWith('http');
    final display = isUrl ? 'Buka tautan' : formatValue(key, value);
    return KeyValueRow(
      label: labelify(key),
      value: display,
      onTapValue: isUrl ? () => openExternal(context, value) : null,
    );
  }

  // ------------------------------------------------------------ list

  Widget _renderList(BuildContext context, List v, int d) {
    if (v.isEmpty) {
      return Text('-',
          style: TextStyle(color: context.textMuted, fontSize: 13));
    }
    if (v.every((e) => e is Map)) {
      return Column(
        children: [
          for (var i = 0; i < v.length; i++) _itemCard(context, i, asMap(v[i]), d),
        ],
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in v)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: context.softFill,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              e.toString(),
              style: TextStyle(
                  fontSize: 12,
                  color: context.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  static const _titleKeys = [
    'nama', 'nama_mk', 'nm_mk', 'mata_kuliah', 'judul', 'title', 'name',
    'kegiatan', 'komponen', 'kode', 'label', 'periode_label', 'tanggal',
  ];

  Widget _itemCard(BuildContext context, int index, Map<String, dynamic> item, int d) {
    final title = pickString(item, [
      'nama_mk', 'nm_mk', 'mata_kuliah', 'judul', 'kegiatan', 'komponen',
      'nama', 'title', 'label',
    ], 'Item ${index + 1}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: context.border),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.amber.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SmartJson(
              data: item,
              excludeKeys: _titleKeys,
              depth: d + 1,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------- primitive

  Widget _renderPrimitive(BuildContext context, dynamic v) {
    if (v is String && v.startsWith('http')) {
      return InkWell(
        onTap: () => openExternal(context, v),
        child: Text(
          v,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.indigo500,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    }
    return Text(
      formatValue('', v),
      style: TextStyle(fontSize: 13, color: context.textPrimary),
    );
  }
}
