import 'whatsapp_target.dart';

/// A single configuration problem found by `WhatsAppShare.diagnose()`.
class DiagnosticIssue {
  /// Creates a diagnostic issue.
  const DiagnosticIssue({
    required this.code,
    required this.description,
    required this.remedy,
  });

  /// Builds an issue from a platform channel payload.
  factory DiagnosticIssue.fromMap(Map<Object?, Object?> map) => DiagnosticIssue(
        code: map['code'] as String? ?? 'UNKNOWN',
        description: map['description'] as String? ?? '',
        remedy: map['remedy'] as String? ?? '',
      );

  /// Stable identifier for the problem, for example `MISSING_QUERIES_TAG`.
  final String code;

  /// What is wrong, in developer-facing terms.
  final String description;

  /// The concrete change that fixes it.
  final String remedy;

  @override
  String toString() => '[$code] $description\n  Fix: $remedy';
}

/// A report on whether the host app is correctly configured for this package.
///
/// Most WhatsApp sharing bugs are host-app configuration problems — a missing
/// `LSApplicationQueriesSchemes` entry on iOS, or a stripped `<queries>` tag on
/// Android — which otherwise surface as a silent "WhatsApp is not installed".
/// Call `WhatsAppShare.diagnose()` in debug builds to surface them directly.
class WhatsAppDiagnostics {
  /// Creates a diagnostics report.
  const WhatsAppDiagnostics({
    required this.platform,
    required this.installedTargets,
    required this.issues,
  });

  /// Builds a report from a platform channel payload.
  factory WhatsAppDiagnostics.fromMap(Map<Object?, Object?> map) {
    final rawTargets =
        (map['installedTargets'] as List<Object?>? ?? <Object?>[])
            .whereType<String>()
            .map(WhatsAppTarget.fromWireName)
            .toSet();
    final rawIssues = (map['issues'] as List<Object?>? ?? <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map(DiagnosticIssue.fromMap)
        .toList(growable: false);
    return WhatsAppDiagnostics(
      platform: map['platform'] as String? ?? 'unknown',
      installedTargets: rawTargets,
      issues: rawIssues,
    );
  }

  /// The platform the report was produced on, for example `android`.
  final String platform;

  /// The WhatsApp apps detected on the device.
  final Set<WhatsAppTarget> installedTargets;

  /// Configuration problems found, empty when everything checks out.
  final List<DiagnosticIssue> issues;

  /// Whether the host app is correctly configured.
  bool get isHealthy => issues.isEmpty;

  @override
  String toString() {
    final buffer = StringBuffer('WhatsApp Share diagnostics ($platform)\n');
    buffer.writeln(
      '  Installed: ${installedTargets.isEmpty ? 'none' : installedTargets.map((t) => t.displayName).join(', ')}',
    );
    if (issues.isEmpty) {
      buffer.writeln('  No configuration issues found.');
    } else {
      for (final issue in issues) {
        buffer.writeln('  $issue');
      }
    }
    return buffer.toString();
  }
}
