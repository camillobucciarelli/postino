import 'package:postino/core/domain/report_sharer.dart';

/// Records every share instead of opening the system share sheet: (text, name, subject).
class FakeReportSharer() implements ReportSharer {
  final shared = <(String text, String name, String subject)>[];

  /// While set, a share throws it: the sheet could not open.
  Exception? failure;
  @override
  Future<void> share({required String text, required String name, required String subject}) async {
    if (failure case final f?) throw f;
    shared.add((text, name, subject));
  }
}
