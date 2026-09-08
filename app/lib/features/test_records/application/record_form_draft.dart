import 'package:flutter_riverpod/legacy.dart';

const _notProvided = Object();

/// In-memory form state for a manual record or a saved record being edited.
///
/// The provider is deliberately not auto-disposed: navigating away from the
/// detection tab must not silently discard user input. A successful save or
/// the explicit "放弃草稿" action is responsible for clearing it.
class RecordFormDraft {
  const RecordFormDraft({
    required this.tankId,
    required this.parameterId,
    required this.reagentProfileId,
    required this.isRange,
    required this.minValueText,
    required this.maxValueText,
    required this.confirmedAt,
    required this.notes,
    this.interpolationText = '',
  });

  final String tankId;
  final String parameterId;
  final String? reagentProfileId;
  final bool isRange;
  final String minValueText;
  final String maxValueText;
  final DateTime confirmedAt;
  final String notes;
  final String interpolationText;

  RecordFormDraft copyWith({
    String? tankId,
    String? parameterId,
    Object? reagentProfileId = _notProvided,
    bool? isRange,
    String? minValueText,
    String? maxValueText,
    DateTime? confirmedAt,
    String? notes,
    String? interpolationText,
  }) {
    return RecordFormDraft(
      tankId: tankId ?? this.tankId,
      parameterId: parameterId ?? this.parameterId,
      reagentProfileId: identical(reagentProfileId, _notProvided)
          ? this.reagentProfileId
          : reagentProfileId as String?,
      isRange: isRange ?? this.isRange,
      minValueText: minValueText ?? this.minValueText,
      maxValueText: maxValueText ?? this.maxValueText,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      notes: notes ?? this.notes,
      interpolationText: interpolationText ?? this.interpolationText,
    );
  }
}

final recordFormDraftProvider = StateProvider.family<RecordFormDraft?, String>(
  (ref, key) => null,
);
