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
//
// `msstore/keyword_locales.txt` decides which locales publish keywords, because
// the Store caps how many locales carry them at all and a tree that is valid
// locale by locale is still refused as a submission. The file is optional:
// without it every committed keyword list is sent, and the assembler's own
// count check is what says so before the Store does.

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
/// Microsoft's MSIX page and the Partner Center form both say "no more than 21
/// separate words across all keywords", and the field the refusal names is
/// `KeywordsTotalCount` — a count of words, not of keywords. A hyphen splits
/// like a space, so `Wi-Fi` spends two, and repeats are not de-duplicated. This
/// is why `--check` used to call the Spanish, Italian, Portuguese and Russian
/// lists legal at 20 words while the Store counted 22: each of them writes
/// `Wi-Fi` twice.
const int maxKeywordWordCount = 21;

/// Keyword words the whole submission may spend, across every locale.
///
/// The same number, applied one level up. Which level the server applies is
/// what three refused releases got wrong in both directions:
///
///     {"code":"InvalidParameterValue","message":"The size of KeywordsTotalCount
///      must be 21 or less","source":"Ingestion Api","target":"keywords"}
///
/// The 2026-11-18 and 2026-11-22 payloads sent keywords in 29 locales and were
/// refused with a per-locale reading of 20 words as the widest list; the
/// 2026-11-22+87 payload cleared 19 of them, sent 10 locales at 70 keywords and
/// 192 counted words, and was refused again — which kills the count-of-locales
/// reading that file was written for. prof18/pcenter-cli records that reading
/// from the same message, and allodia-eu/mail-calendar, which probed the
/// ingestion API against a throwaway draft on 2026-08-03, records the word
/// reading and the hyphen split. Nothing has yet been published inside 21 words
/// total, and nothing has been refused while sitting inside it, so the number
/// stays ambiguous and the script enforces both: a submission under
/// [maxKeywordWordCount] words in total is under it per locale for free, and it
/// is the only shape that cannot be refused by either reading.
const int maxSubmissionKeywordWords = 21;

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

/// The locales allowed to spend the submission's keyword words, one Store tag
/// per line.
///
/// Because [maxSubmissionKeywordWords] is shared, the tree cannot give every
/// market a full list: seven ordinary terms already cost 19 to 22 words. This
/// file chooses who gets the budget, and a locale outside it publishes with
/// `Keywords` cleared and keeps its `keywords.txt` in git for when the budget
/// moves. Which market deserves it is a judgement about audience, not a limit,
/// so it stays a reviewed file rather than a constant.
const String keywordLocalesFile = 'keyword_locales.txt';

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
List<String> readReservedTitles(Directory root) =>
    _readRootFile(root, reservedTitlesFile);

/// The locales allowed keywords, or empty when the file is absent and the
/// Store's own count is the only limit that applies.
List<String> readKeywordLocales(Directory root) =>
    _readRootFile(root, keywordLocalesFile);

/// One line-per-entry file at the root of the listing tree, CRLF tolerant.
List<String> _readRootFile(Directory root, String name) {
  final file = File('${root.path}${Platform.pathSeparator}$name');
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

/// Keyword words each publishing locale spends, biggest spender first.
///
/// The unit of the Store's `KeywordsTotalCount` is the word, so this is what a
/// refusal is actually about, and naming the lists is what makes the message
/// fixable: the count is one budget, and the only lever a contributor has is
/// which locales [keywordLocalesFile] names and how long their terms are. A
/// locale outside that list is not in the map because [overlaySubmission]
/// blanks it, and a locale with no `keywords.txt` is not in it because git
/// declares nothing to send.
Map<String, int> keywordSpend(
  List<ListingLocale> locales,
  List<String> keywordLocales,
) {
  final spend = <String, int>{};
  for (final locale in locales) {
    if (keywordLocales.isNotEmpty && !keywordLocales.contains(locale.locale)) {
      continue;
    }
    final keywords = locale.fields['Keywords'];
    if (keywords is! List<String>) continue;
    final words = keywordWords(keywords).length;
    if (words > 0) spend[locale.locale] = words;
  }
  final ordered = spend.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return {for (final entry in ordered) entry.key: entry.value};
}

/// Separators the Store splits a keyword on: whitespace and the three hyphens
/// that survive a copy out of a word processor.
final RegExp _keywordSeparators = RegExp(r'[\s\-‐‑]+');

/// Punctuation the Store keeps inside a word, so a quote or a full stop must not
/// inflate the count. Mirrors the set allodia-eu/mail-calendar measured.
final RegExp _keywordPunctuation = RegExp(
  r'''^[.,;:!?\[\]()"'«»’]+|[.,;:!?\[\]()"'«»’]+$''',
);

/// The words the Store counts in [keywords], repeats included.
///
/// `[maxKeywordWordCount]` reads "21 separate words", which invites a count of
/// distinct words; the measured behaviour is a count of words. Seven copies of
/// `aa bb` spend 14 there and 2 in a set, and only the first agrees with the
/// server.
List<String> keywordWords(Iterable<String> keywords) {
  final words = <String>[];
  for (final keyword in keywords) {
    for (final part in keyword.split(_keywordSeparators)) {
      final word = part.replaceAll(_keywordPunctuation, '').toLowerCase();
      if (word.isNotEmpty) words.add(word);
    }
  }
  return words;
}

/// Every limit and completeness problem across the tree, in one report, so a
/// contributor sees all of them from a single run.
List<String> validateListingTree(
  List<ListingLocale> locales, {
  List<String> keywordLocales = const [],
}) {
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
      // A locale outside the keyword budget publishes an empty list, so nothing
      // its keywords.txt holds reaches the Store and no limit on it can be
      // breached. These checks start applying the moment the budget names it,
      // which is the point where the copy becomes somebody else's refusal.
      if (entry.key == 'Keywords' &&
          keywordLocales.isNotEmpty &&
          !keywordLocales.contains(locale.locale)) {
        continue;
      }
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
          final words = keywordWords(value).length;
          if (words > maxKeywordWordCount) {
            violations.add('$prefix uses $words words across all entries, '
                'the limit is $maxKeywordWordCount, and every word it spends '
                'comes out of the $maxSubmissionKeywordWords the whole '
                'submission shares');
          }
        }
      }
    }
  }
  final declared = locales.map((locale) => locale.locale).toSet();
  for (final stray in keywordLocales.where((tag) => !declared.contains(tag))) {
    violations.add('$keywordLocalesFile names $stray, which the tree does not '
        'carry: a typo or a parked locale spends nothing and sends nothing');
  }
  final spend = keywordSpend(locales, keywordLocales);
  final used = spend.values.fold<int>(0, (a, b) => a + b);
  if (used > maxSubmissionKeywordWords) {
    violations.add(
      'the keyword lists that publish spend $used words, and the Store '
      'refuses a submission over $maxSubmissionKeywordWords '
      '(KeywordsTotalCount): ${spend.entries.map((e) => '${e.key}=${e.value}').join(', ')} '
      '— a hyphen counts as a space, so shorten the biggest lists or move '
      'the locale out of $keywordLocalesFile and publish it blank',
    );
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
  List<String> keywordLocales = const [],
}) {
  final violations =
      validateListingTree(locales, keywordLocales: keywordLocales);
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
  final blanked = <String>[];
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
    final keywords = fields['Keywords'];
    if (keywordLocales.isNotEmpty &&
        !keywordLocales.contains(locale.locale) &&
        keywords is List &&
        keywords.isNotEmpty) {
      // The empty list is the write: leaving the field alone keeps whatever the
      // captured draft serves, and those words spend the submission's budget
      // whether git named the locale or not, so the refusal would come back
      // unchanged.
      fields['Keywords'] = <String>[];
      blanked.add(locale.locale);
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

  if (blanked.isNotEmpty) {
    stderr.writeln(
      '${blanked.length} locale(s) publish with Keywords cleared because they '
      'are not named in $defaultListingsDirectory/$keywordLocalesFile: '
      '${blanked.join(', ')}. The $maxSubmissionKeywordWords keyword words the '
      'Store allows are one budget shared by the submission, so the words stay '
      'in git and the spend goes to the named locales. Add a tag to that file '
      'to give one keywords, and keep the total inside the budget.',
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
    final keywordLocales = readKeywordLocales(options.listingsDirectory);
    if (options.checkOnly) {
      final violations =
          validateListingTree(locales, keywordLocales: keywordLocales);
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
      keywordLocales: keywordLocales,
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
