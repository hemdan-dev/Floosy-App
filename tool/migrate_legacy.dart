import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:floosy/migration/legacy_parser.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';

Future<void> main(List<String> arguments) async {
  final sourcePath = _value(arguments, '--source') ?? 'unstractures_data.txt';
  final outputDirectory = Directory(
    _value(arguments, '--output') ?? 'migration-output',
  );
  final allowDifferent = arguments.contains('--allow-different');
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Source file not found: $sourcePath');
    exitCode = 2;
    return;
  }

  final source = await sourceFile.readAsString();
  final parsed = buildLegacyBaseline(
    source,
    requireKnownDataset: !allowDifferent,
  );
  await outputDirectory.create(recursive: true);
  final jsonBytes = utf8.encode(jsonEncode(parsed.baseline));
  final baselineBytes = Uint8List.fromList(gzip.encode(jsonBytes));
  final baselineFile = File(
    '${outputDirectory.path}/floosy-baseline-v1.json.gz',
  );
  final reportFile = File('${outputDirectory.path}/migration-report.json');
  await baselineFile.writeAsBytes(baselineBytes, flush: true);
  await reportFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(parsed.report),
    flush: true,
  );

  stdout.writeln(const JsonEncoder.withIndent('  ').convert(parsed.report));
  stdout.writeln('Baseline: ${baselineFile.absolute.path}');
  stdout.writeln('Report: ${reportFile.absolute.path}');

  if (!arguments.contains('--upload')) return;
  final clientId = _value(arguments, '--client-id');
  final clientSecret = _value(arguments, '--client-secret');
  if (clientId == null || clientSecret == null) {
    stderr.writeln('--upload requires --client-id and --client-secret.');
    exitCode = 2;
    return;
  }
  final client = await clientViaUserConsent(
    ClientId(clientId, clientSecret),
    [drive.DriveApi.driveAppdataScope],
    (url) {
      stdout.writeln('Open this URL in a browser and approve Drive access:');
      stdout.writeln(url);
    },
  );
  try {
    final api = drive.DriveApi(client);
    const name = 'floosy-baseline-v1.json.gz';
    final matches = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$name' and trashed = false",
      $fields: 'files(id,name)',
    );
    final media = drive.Media(
      Stream.value(baselineBytes),
      baselineBytes.length,
      contentType: 'application/gzip',
    );
    if (matches.files?.isNotEmpty ?? false) {
      await api.files.update(
        drive.File(name: name),
        matches.files!.first.id!,
        uploadMedia: media,
      );
    } else {
      await api.files.create(
        drive.File(name: name, parents: const ['appDataFolder']),
        uploadMedia: media,
      );
    }
    stdout.writeln('Uploaded $name to the private Google Drive appDataFolder.');
  } finally {
    client.close();
  }
}

String? _value(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  return index >= 0 && index + 1 < arguments.length
      ? arguments[index + 1]
      : null;
}
