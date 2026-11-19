// Assembles the Microsoft Store submission payload from this checkout.
//
// The Store replaces the whole submission on every update, so a listing
// publish has to send the live submission with this repository's words
// overlaid onto it: packages, screenshots and pricing come from the store,
// description, features, keywords and release notes come from git.
//
//     dart run scripts/ms_store_listing.dart \
//       --submission captured.json --listings msstore --out payload.json
//
// `.github/workflows/ms_store_release.yml` runs that between uploading the
// release package into a draft submission and committing it, so the package and
// its listing text reach the Store as one submission.
//
// `msstore/pending/` holds the locales written but not yet enabled on the
// product; the tree reader only matches locale-shaped directory names, so they
// sit in review without reaching a payload.
//
// `--check` validates the locale tree on its own, which is the half a pull
// request can run without Store credentials.
//
// A locale directory that the live submission does not carry is refused rather
// than added: the language has to be enabled on the product in Partner Center
// first, and `--allow-new-locales` says that has been done.

import 'dart:convert';
import 'dart:io';

const String listingField = 'Listings';
const String baseListingField = 'BaseListing';
const String platformOverridesField = 'PlatformOverrides';

/// Store limits for the fields this script owns, from Microsoft's MSIX listing
/// documentation. A payload over any of these is rejected by the API.
const Map<String, int> maxTextLength = {
  'Title': 256,
  'ShortDescription': 1000,
  'Description': 10000,
  'ReleaseNotes': 1500,
};

const Map<String, int> maxListLength = {'Features': 20, 'Keywords': 7};
const int maxListItemLength = 40;
const int maxFeatureLength = 200;

/// Words the seven keywords of one listing may use between them.
///
/// Microsoft states the budget two ways — "21 unique words TOTAL across all
/// search terms" in the submission API table and "no more than 21 separate
/// words across all keywords" in the MSIX page and the Partner Center form —
/// and only the stricter reading is enforceable from git. On 2026-11-18 the
/// Store refused a 29-locale payload with `KeywordsTotalCount must be 21 or
/// less` while every `vi-vn` keyword was unique, 24 words in seven entries;
/// blanking `Keywords` on every listing made the same payload accepted. So the
/// count is per locale and it counts occurrences, not distinct words, and a
/// refusal that names no locale costs a Store round trip to find.
const int maxKeywordWordCount = 21;

/// A comma where a list file should have had a newline.
///
/// `features.txt` and `keywords.txt` become one payload entry per line, so a
/// file that separates its bullets with commas publishes a single bullet. All
/// 29 locales did that with their features until 2026-11-19, and the storefront
/// showed one feature per language instead of ten — no limit was breached, so
/// nothing failed. The Arabic comma is in the class because `ar-sa` joined
/// itself with `،` and a Latin-only check would have called it clean.
final RegExp commaJoinedList = RegExp(',\\s|\u060C');

/// File name -> submission field, in the order the payload reports them.
const Map<String, String> fileToField = {
  'title.txt': 'Title',
  'short_description.txt': 'ShortDescription',
  'description.txt': 'Description',
  'release_notes.txt': 'ReleaseNotes',
  'features.txt': 'Features',
  'keywords.txt': 'Keywords',
};

/// Product names Partner Center has reserved for this submission.
///
/// A locale the package does not serve can only be listed under one of these,
/// so a `title.txt` outside the set is skipped instead of published: the Store
/// refuses a submission that renames a listing to a name nobody reserved. The
/// localized taglines stay committed and go live by adding their name here once
/// it is reserved.
const String reservedTitlesFile = 'reserved_titles.txt';

/// Fields a locale directory must provide to be publishable at all.
const List<String> requiredFiles = ['title.txt', 'description.txt'];

/// The listing tree, deliberately at the repository root instead of `metadata/`.
///
/// fdroidserver scans `build/<package>/metadata/<locale>` in this checkout and
/// copies whatever text it finds over the values read from fastlane, so a
/// `metadata/` directory here is an ungoverned second F-Droid listing: the
/// Windows prose would replace the Android one, whose summary limit is 80
/// characters, and `pending/` would arrive as languages no store serves.
const String defaultListingsDirectory = 'msstore';

/// A locale directory is the language tag the Store itself reports, and a region
/// is not always part of it: the 2026-11-18 capture served `ru` bare alongside
/// `cs-cz`, `it-it`, `pl-pl` and `sk-sk`, while `pt-br`, `es-es` and `es-419`
/// carried one. The region group is optional so the tree can match the capture
/// either way, and `pending` still fails the pattern, which is what keeps an
/// unenabled language out of a payload. It is a shape filter, not Microsoft's
/// list: a tag the product does not serve reads here and is the Store's
/// rejection to answer, so the release's capture decides the spelling, not a
/// table.
final RegExp localeDirectoryPattern = RegExp(r'^[a-z]{2,3}(-[a-z0-9]{2,4})?$');

/// One locale's listing text, with a null value meaning "no file committed,
/// leave whatever the live submission holds".
class ListingLocale {
  ListingLocale(this.locale, this.fields);

  final String locale;
  final Map<String, Object?> fields;
}

class ListingFailure implements Exception {
  ListingFailure(this.violations);

  final List<String> violations;

  @override
  String toString() => violations.join('\n');
}

/// Reads `msstore/<locale>/` and returns every locale it declares.
List<ListingLocale> readListingTree(Directory root) {
  if (!root.existsSync()) {
    throw ListingFailure(['no listing tree at ${root.path}']);
  }
  final locales = <ListingLocale>[];
  for (final entity in root.listSync()) {
    if (entity is! Directory) continue;
    final name = _baseName(entity.path);
    if (!localeDirectoryPattern.hasMatch(name)) continue;
    final fields = <String, Object?>{};
    for (final mapping in fileToField.entries) {
      final file =
          File('${entity.path}${Platform.pathSeparator}${mapping.key}');
      if (!file.existsSync()) {
        fields[mapping.value] = null;
        continue;
      }
      fields[mapping.value] = _fieldValue(
        mapping.value,
        file
            .readAsStringSync()
            .replaceAll('\r\n', '\n')
            .replaceFirst(RegExp(r'\n$'), ''),
      );
    }
    locales.add(ListingLocale(name, fields));
  }
  return locales..sort((a, b) => a.locale.compareTo(b.locale));
}

/// The reserved product names, or empty when the file is absent and nothing is
/// enforced.
List<String> readReservedTitles(Directory root) {
  final file = File('${root.path}${Platform.pathSeparator}$reservedTitlesFile');
  if (!file.existsSync()) return const [];
  return file
      .readAsStringSync()
      .replaceAll('\r\n', '\n')
      .split('\n')
      .where((line) => line.isNotEmpty)
      .toList();
}

String _baseName(String path) =>
    path.replaceAll('\\', '/').split('/').where((part) => part.isNotEmpty).last;

Object? _fieldValue(String field, String content) {
  if (!maxListLength.containsKey(field)) return content;
  return content.split('\n').where((line) => line.isNotEmpty).toList();
}

/// Every limit and completeness problem across the tree, in one report, so a
/// contributor sees all of them from a single run.
List<String> validateListingTree(List<ListingLocale> locales) {
  final violations = <String>[];
  if (locales.isEmpty) violations.add('the listing tree declares no locales');
  for (final locale in locales) {
    for (final name in requiredFiles) {
      final field = fileToField[name];
      final value = field == null ? null : locale.fields[field];
      if (value == null || (value is String && value.trim().isEmpty)) {
        violations.add('${locale.locale}: $name is required');
      }
    }
    for (final entry in locale.fields.entries) {
      final value = entry.value;
      if (value == null) continue;
      final prefix = '${locale.locale}: ${entry.key}';
      if (value is String) {
        final max = maxTextLength[entry.key];
        if (max != null && value.length > max) {
          violations
              .add('$prefix is ${value.length} characters, the limit is $max');
        }
      } else if (value is List<String>) {
        final max = maxListLength[entry.key];
        if (max != null && value.length > max) {
          violations
              .add('$prefix has ${value.length} entries, the limit is $max');
        }
        final perItem =
            entry.key == 'Features' ? maxFeatureLength : maxListItemLength;
        for (final item in value.where((item) => item.length > perItem)) {
          violations.add(
              '$prefix entry is ${item.length} characters, the limit is $perItem');
        }
        if (value.length == 1 && commaJoinedList.hasMatch(value.single)) {
          violations.add(
              '$prefix is one comma-joined line; put each entry on its own line');
        }
        if (entry.key == 'Keywords') {
          final words = value
              .expand((item) => item.trim().split(RegExp(r'\s+')))
              .where((word) => word.isNotEmpty)
              .length;
          if (words > maxKeywordWordCount) {
            violations.add('$prefix uses $words words across all entries, '
                'the limit is $maxKeywordWordCount');
          }
        }
      }
    }
  }
  return violations;
}

/// What [fields] rewrites inside one captured listing, as sizes rather than
/// text.
///
/// A listing publish is the one Store operation whose payload is prose, and a
/// CI log is public: `Title 26 -> 27 chars` tells a reviewer whether the run
/// moved what they expected without copying the description into the run log.
List<String> describeOverlayChanges(
  String locale,
  Map<String, dynamic> captured,
  Map<String, Object?> fields,
) {
  final changes = <String>[];
  for (final entry in fields.entries) {
    final incoming = entry.value;
    if (incoming == null) continue;
    final previous = captured[entry.key];
    if (previous is List &&
        incoming is List &&
        previous.join('\n') == incoming.join('\n')) {
      continue;
    }
    if (previous is String && previous == incoming) continue;
    final from = _size(previous);
    final to = _size(incoming);
    changes.add('$locale: ${entry.key} $from -> $to');
  }
  return changes;
}

String _size(Object? value) {
  if (value == null) return 'absent';
  if (value is String) return '${value.length} chars';
  if (value is List) {
    final count = value.length;
    return '$count ${count == 1 ? 'entry' : 'entries'}';
  }
  return 'set';
}

/// Overlays [locales] onto a captured [submission] and returns the payload.
///
/// Everything the tree does not declare — packages, images, hardware, markets —
/// is carried through byte for byte, and so is every locale that exists in the
/// store but not yet in git.
Map<String, dynamic> overlaySubmission(
  Map<String, dynamic> submission,
  List<ListingLocale> locales, {
  bool allowNewLocales = false,
  List<String> reservedTitles = const [],
}) {
  final violations = validateListingTree(locales);
  final Object? listings = submission[listingField];
  if (listings is! Map) {
    throw ListingFailure(
        [...violations, 'the captured submission has no $listingField map']);
  }
  if (violations.isNotEmpty) throw ListingFailure(violations);

  final typed = listings.cast<String, dynamic>();
  final preserved = <String>[];
  final staged = <String>[];
  final unknown = <String>[];
  final unreserved = <String>[];
  final added = <String>[];
  final changes = <String>[];

  for (final entry in typed.keys.toList()) {
    if (!locales.any((locale) => locale.locale == entry)) preserved.add(entry);
  }

  for (final locale in locales) {
    var listing = typed[locale.locale];
    if (listing == null) {
      if (!allowNewLocales) {
        unknown.add(locale.locale);
        continue;
      }
      listing = <String, dynamic>{baseListingField: <String, dynamic>{}};
      typed[locale.locale] = listing;
      added.add(locale.locale);
    }
    if (listing is! Map) {
      throw ListingFailure(
          ['${locale.locale}: the captured listing is not an object']);
    }
    Object? base = listing.cast<String, dynamic>()[baseListingField];
    if (base is! Map) {
      base = <String, dynamic>{};
      listing[baseListingField] = base;
    }
    final baseListing = base.cast<String, dynamic>();
    final fields = Map<String, Object?>.from(locale.fields);
    final title = fields['Title'];
    if (reservedTitles.isNotEmpty &&
        title is String &&
        !reservedTitles.contains(title)) {
      fields.remove('Title');
      unreserved.add('${locale.locale} (${title.length})');
    }
    changes.addAll(describeOverlayChanges(locale.locale, baseListing, fields));
    fields.forEach((field, value) {
      if (value != null) baseListing[field] = value;
    });
    listing.putIfAbsent(platformOverridesField, () => <String, dynamic>{});
    staged.add(locale.locale);
  }

  for (final locale in added) {
    stderr.writeln(
      '$locale: written into the payload from git, so it carries no '
      'screenshots. The Store wants at least one image per language, which it '
      'can only get from a submission made in Partner Center -- expect this '
      'update to be refused until one has been.',
    );
  }

  if (unreserved.isNotEmpty) {
    stderr.writeln(
      '${unreserved.length} locale(s) keep the title the Store already serves, '
      'because title.txt is not a reserved product name (lengths in chars): '
      '${unreserved.join(', ')}. Reserve each name in Partner Center, then add '
      'it to $defaultListingsDirectory/$reservedTitlesFile to publish it.',
    );
  }

  if (unknown.isNotEmpty) {
    final missing = unknown.join(', ');
    throw ListingFailure([
      'these locales are not enabled on the product, so the Store cannot accept them: $missing',
      'enable each one in Partner Center (Store listing > Add/remove languages), then pass --allow-new-locales',
    ]);
  }

  // The API returns 'Base' for a product priced identically everywhere, which is
  // how a free app is priced, and rejects it on update.
  final pricing = submission['Pricing'];
  if (pricing is Map<String, dynamic>) {
    final priceId = pricing['PriceId'];
    if (priceId == null || priceId == '' || priceId == 'Base') {
      pricing['PriceId'] = 'Free';
    }
  }

  if (changes.isEmpty) {
    stdout.writeln('the listing tree matches what the store already serves');
  }
  for (final change in changes) {
    stdout.writeln(change);
  }

  stdout.writeln(
    'overlaid ${staged.join(', ')}; '
    'kept from the store without a git tree: ${preserved.isEmpty ? 'none' : preserved.join(', ')}; '
    'packages: ${_packageNames(submission)}',
  );
  return submission;
}

String _packageNames(Map<String, dynamic> submission) {
  final packages = submission['ApplicationPackages'];
  if (packages is! List) return 'none';
  final names = packages
      .whereType<Map<String, dynamic>>()
      .map((package) => package['FileName'])
      .whereType<String>()
      .toList();
  return names.isEmpty ? 'none' : names.join(', ');
}

Map<String, dynamic> _readSubmission(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw ListingFailure(['no captured submission at $path']);
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw ListingFailure(['$path did not contain a submission object']);
  }
  return decoded;
}

void main(List<String> args) {
  final _Options? options;
  try {
    options = _Options.parse(args);
  } on ListingFailure catch (failure) {
    for (final violation in failure.violations) {
      stderr.writeln(violation);
    }
    exitCode = 64;
    return;
  }
  if (options == null) {
    stderr.writeln(
      'usage: dart run scripts/ms_store_listing.dart '
      '(--submission <captured.json> --out <payload.json> [--listings <dir>] '
      '[--allow-new-locales] | --check [--listings <dir>])',
    );
    exitCode = 64;
    return;
  }

  try {
    final locales = readListingTree(options.listingsDirectory);
    if (options.checkOnly) {
      final violations = validateListingTree(locales);
      if (violations.isNotEmpty) throw ListingFailure(violations);
      stdout.writeln(
        '${locales.map((locale) => locale.locale).join(', ')}: listing tree is within '
        'every Store limit.',
      );
      return;
    }
    final payload = overlaySubmission(
      _readSubmission(options.submissionPath!),
      locales,
      allowNewLocales: options.allowNewLocales,
      reservedTitles: readReservedTitles(options.listingsDirectory),
    );
    File(options.outputPath!)
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(payload));
    stdout.writeln(
        'wrote ${options.outputPath} (${File(options.outputPath!).lengthSync()} bytes)');
  } on ListingFailure catch (failure) {
    stderr.writeln('listing assembly refused:');
    for (final violation in failure.violations) {
      stderr.writeln('  - $violation');
    }
    exitCode = 1;
  } on FormatException catch (error) {
    stderr
        .writeln('the captured submission is not valid JSON: ${error.message}');
    exitCode = 1;
  }
}

class _Options {
  _Options({
    required this.listingsDirectory,
    this.submissionPath,
    this.outputPath,
    this.allowNewLocales = false,
    this.checkOnly = false,
  });

  final Directory listingsDirectory;
  final String? submissionPath;
  final String? outputPath;
  final bool allowNewLocales;
  final bool checkOnly;

  static _Options? parse(List<String> args) {
    Directory listings = Directory(defaultListingsDirectory);
    String? submission;
    String? output;
    bool allowNew = false;
    bool check = false;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      switch (arg) {
        case '--check':
          check = true;
        case '--allow-new-locales':
          allowNew = true;
        case '--listings':
          listings = Directory(_value(args, ++i, arg));
        case '--submission':
          submission = _value(args, ++i, arg);
        case '--out':
          output = _value(args, ++i, arg);
        default:
          return null;
      }
    }
    if (check) {
      if (submission != null || output != null) return null;
      return _Options(listingsDirectory: listings, checkOnly: true);
    }
    if (submission == null || output == null) return null;
    return _Options(
      listingsDirectory: listings,
      submissionPath: submission,
      outputPath: output,
      allowNewLocales: allowNew,
    );
  }

  static String _value(List<String> args, int index, String flag) {
    if (index >= args.length) throw ListingFailure(['$flag needs a value']);
    return args[index];
  }
}
