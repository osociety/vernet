// Fails a pull request that puts an unqualified privacy or advertising claim in
// published copy.
//
//     dart run scripts/check_store_claims.dart
//
// Vernet is one codebase shipped several ways, and the builds are not equal:
// the Google Play build carries AdMob banners and the in-app review prompt, the
// F-Droid, GitHub, snap, Windows and macOS builds carry neither. So "No
// tracking, no telemetry." is a sentence true of most of those channels and
// false of the Play one, while a reader of any single listing takes it as a
// statement about Vernet. That is how it reached the snap description and stayed
// there: nothing in CI could tell a qualified sentence from a blanket one.
//
// The check is therefore about placement rather than truth. A claim from
// [claimsByLanguage] passes exactly when the sentence it sits in also names the
// build or channel it is true of, from [channelNames]. This passes, and it is
// the wording #578 adopted for the README:
//
//     The Google Play build contains ads. The F-Droid and GitHub builds are
//     ad-free.
//
// A spelling is listed only where it is false of at least one shipping channel,
// which is why "no analytics or crash reporting" is absent — no build ships
// either — while "no tracking" is present, because the Play build's ad SDK
// tracks the device. Matching is whole-word, so a keyword list carrying "IP
// address tracker" is not read as a tracking claim, and an inflected form is its
// own entry: the German listing writes "werbefreie", not "werbefrei".
//
// Non-English copy needs the claim in its own language, so every language the
// store trees serve has a vocabulary entry, and a locale in a language without
// one is itself a finding: adding a language to a listing tree then forces the
// question of what its ad and privacy wording means here. The translations are
// maintainer-written, so a gap costs a missed claim, not a false alarm.
//
// Field lengths and per-tree locale completeness are not this script's job.
// `scripts/play_store_listing.dart --check` and
// `scripts/ms_store_listing.dart --check` already fail a pull request for those
// in the trees they own, and repeating their limits here would only let two sets
// of numbers drift.

import 'dart:io';

/// The tree fastlane publishes to Play, one directory per language.
const String playMetadataDirectory = 'android/fastlane/metadata/android';

/// The tree `scripts/ms_store_listing.dart` overlays onto a live submission.
const String msstoreDirectory = 'msstore';

/// English copy that describes the whole project rather than one build, so it
/// carries the same claims a store listing does.
const List<String> documentFiles = [
  'snap/snapcraft.yaml',
  'README.md',
  'firebase/public/index.html',
];

const List<String> playListingFiles = [
  'title.txt',
  'short_description.txt',
  'full_description.txt',
];

const List<String> msstoreListingFiles = [
  'title.txt',
  'short_description.txt',
  'description.txt',
  'features.txt',
  'keywords.txt',
  'release_notes.txt',
];

/// Play publishes its localized "What's new" from here, and a note is copy too.
const String changelogsDirectory = 'changelogs';

/// A Play language directory: `de-DE`, or the bare `id` and `ar` that Play
/// accepts. fastlane publishes every non-hidden directory in the tree.
final RegExp playLocaleDirectory =
    RegExp(r'^([a-z]{2,3})(-[A-Za-z0-9]{2,4})?$');

/// A Windows Store language directory. The dash is required, which is what keeps
/// `msstore/pending/` — copy written for languages not yet enabled in Partner
/// Center — out of this scan, as it keeps it out of the publish.
final RegExp msstoreLocaleDirectory = RegExp(r'^([a-z]{2,3})(-[a-z0-9]{2,4})$');

/// Locale codes the store trees use for a language, when the code itself is not
/// the language: `iw` is Hebrew, `no` is Norwegian bokmål.
const Map<String, String> languageAliases = {'iw': 'he', 'no': 'nb'};

/// Spellings that assert something no shipping channel can promise across the
/// board: no ads, no tracking, no telemetry. Keys are the language part of a
/// store locale code, in lower case.
const Map<String, List<String>> claimsByLanguage = {
  'ar': [
    'بدون إعلانات',
    'لا إعلانات',
    'بلا إعلانات',
    'خالي من الإعلانات',
    'بدون تتبع',
    'لا تتبع',
    'بدون القياس عن بعد',
  ],
  'cs': [
    'bez reklam',
    'bez reklamy',
    'žádné reklamy',
    'bez sledování',
    'žádné sledování',
    'bez trackingu',
    'bez telemetrie',
  ],
  'da': [
    'reklamefri',
    'uden reklamer',
    'uden reklame',
    'ingen reklamer',
    'uden sporing',
    'uden tracking',
    'ingen sporing',
    'ingen tracking',
    'uden telemetri',
    'ingen telemetri',
  ],
  'de': [
    'werbefrei',
    'werbefreie',
    'ohne werbung',
    'keine werbung',
    'kein tracking',
    'ohne tracking',
    'keine verfolgung',
    'ohne verfolgung',
    'keine telemetrie',
    'ohne telemetrie',
  ],
  'en': [
    'no ads',
    'ad-free',
    'ad free',
    'advert-free',
    'without ads',
    'no advertising',
    'zero ads',
    'no tracking',
    'no user tracking',
    'zero tracking',
    'we do not track',
    "we don't track",
    'no telemetry',
    'zero telemetry',
    'no data collection',
    'collects no data',
  ],
  'es': [
    'sin anuncios',
    'sin publicidad',
    'libre de anuncios',
    'libre de publicidad',
    'sin rastreo',
    'sin seguimiento',
    'sin recolección de datos',
    'sin telemetría',
  ],
  'fi': [
    'mainokseton',
    'ilman mainoksia',
    'ei mainoksia',
    'ilman seurantaa',
    'ei seurantaa',
    'ilman telemetriaa',
    'ei telemetriaa',
  ],
  'fr': [
    'sans publicité',
    'sans pub',
    'sans annonces',
    'sans annonce',
    'aucune publicité',
    'libre de publicité',
    'sans suivi',
    'sans pistage',
    'aucun suivi',
    'pas de suivi',
    'sans télémétrie',
    'aucune télémétrie',
  ],
  'he': [
    'ללא פרסומות',
    'בלי פרסומות',
    'אין פרסומות',
    'ללא מעקב',
    'בלי מעקב',
    'אין מעקב',
    'ללא טלמטריה',
    'אין טלמטריה',
  ],
  'hi': [
    'विज्ञापन नहीं',
    'कोई विज्ञापन नहीं',
    'विज्ञापन रहित',
    'बिना विज्ञापन',
    'ट्रैकिंग नहीं',
    'कोई ट्रैकिंग नहीं',
    'टेलीमेट्री नहीं',
  ],
  'hu': [
    'reklámmentes',
    'reklám nélkül',
    'nincs reklám',
    'követés nélkül',
    'követésmentes',
    'nincs követés',
    'telemetria nélkül',
    'nincs telemetria',
  ],
  'id': [
    'tanpa iklan',
    'bebas iklan',
    'tidak ada iklan',
    'tanpa pelacakan',
    'tidak melacak',
    'tanpa telemetri',
  ],
  'it': [
    'senza pubblicità',
    'senza pubblicita',
    'senza annunci',
    'nessuna pubblicità',
    'senza tracciamento',
    'nessun tracciamento',
    'senza telemetria',
    'nessuna telemetria',
  ],
  'ja': ['広告なし', '広告を含まない', 'トラッキングなし', '追跡なし', 'テレメトリなし'],
  'ko': [
    '광고 없음',
    '광고 없이',
    '광고가 없습니다',
    '추적 없음',
    '추적 없이',
    '텔레메트리 없음',
  ],
  'nb': [
    'annonsefri',
    'uten annonser',
    'ingen annonser',
    'uten reklame',
    'ingen reklame',
    'uten sporing',
    'uten tracking',
    'ingen sporing',
    'ingen tracking',
    'uten telemetri',
    'ingen telemetri',
  ],
  'nl': [
    'advertentievrij',
    'zonder reclame',
    'geen reclame',
    'zonder advertenties',
    'geen advertenties',
    'zonder tracking',
    'geen tracking',
    'zonder telemetrie',
    'geen telemetrie',
  ],
  'pl': [
    'bez reklam',
    'bez reklamy',
    'brak reklam',
    'bez śledzenia',
    'brak śledzenia',
    'bez trackingu',
    'bez telemetrii',
  ],
  'pt': [
    'sem anúncios',
    'sem anuncio',
    'sem publicidade',
    'livre de anúncios',
    'sem rastreamento',
    'sem monitoramento',
    'sem telemetria',
  ],
  'ro': [
    'fără reclame',
    'fara reclame',
    'fără publicitate',
    'zero reclame',
    'fără anunțuri',
    'fără urmărire',
    'zero urmărire',
    'fără telemetrie',
  ],
  'ru': [
    'без рекламы',
    'без реклам',
    'нет рекламы',
    'не содержит рекламы',
    'без отслеживания',
    'нет отслеживания',
    'без слежения',
    'без телеметрии',
  ],
  'sk': [
    'bez reklamy',
    'bez reklam',
    'žiadne reklamy',
    'bez sledovania',
    'bez telemetrie'
  ],
  'sv': [
    'reklafri',
    'utan reklam',
    'ingen reklam',
    'utan annonser',
    'inga annonser',
    'utan spårning',
    'ingen spårning',
    'utan tracking',
    'ingen tracking',
    'utan telemetri',
    'ingen telemetri',
  ],
  'th': [
    'ไม่มีโฆษณา',
    'ไร้โฆษณา',
    'ไม่มีการโฆษณา',
    'ไม่มีการติดตาม',
    'ไม่ติดตาม',
    'ไม่มีเทเลเมตรี',
  ],
  'tr': [
    'reklamsız',
    'reklam yok',
    'reklam içermez',
    'takip yok',
    'takip içermez',
    'izleme yok',
    'telemetri yok',
  ],
  'uk': [
    'без реклами',
    'немає реклами',
    'без реклам',
    'без відстеження',
    'немає відстеження',
    'без телеметрії',
  ],
  'vi': [
    'không quảng cáo',
    'không có quảng cáo',
    'không theo dõi',
    'không giám sát',
    'không telemetry',
  ],
  'zh': ['无广告', '不含广告', '没有广告', '无跟踪', '不跟踪', '无追踪', '无遥测'],
};

/// Build and channel names that make a claim local. They are brands and platform
/// words, so one list serves every language, plus the ways a listing says "this
/// build" in the languages the store trees serve.
const List<String> channelNames = [
  'google play',
  'play store',
  'f-droid',
  'fdroid',
  'github',
  'snap store',
  'snapcraft',
  'microsoft store',
  'app store',
  'windows',
  'macos',
  'linux',
  'android',
  'ios',
  'this build',
  'these builds',
  'this version',
  'diese version',
  'denne version',
  'deze versie',
  'deze build',
  'cette version',
  'questa versione',
  'esta versión',
  'essa versão',
  'denna version',
  'den här versionen',
  'tämä versio',
  'această versiune',
  'ta wersja',
  'tena wersja',
  'tato verze',
];

/// One published text: a file a store serves copy from, in one language.
class ListingText {
  const ListingText({
    required this.path,
    required this.language,
    required this.body,
  });

  final String path;

  /// The language part of a store locale code, after [languageAliases], or `en`
  /// for the project-wide documents.
  final String language;
  final String body;
}

/// A sentence of published copy, with the place a contributor has to edit to
/// change it.
class ClaimSentence {
  const ClaimSentence({
    required this.path,
    required this.language,
    required this.line,
    required this.text,
  });

  final String path;
  final String language;

  /// The first line of the sentence in [path].
  final int line;
  final String text;
}

/// The base language a store locale directory is written in, or null when the
/// directory is not a locale at all.
String? languageForLocaleDirectory(String name, RegExp pattern) {
  final match = pattern.firstMatch(name);
  if (match == null) return null;
  final base = match.group(1)!;
  return languageAliases[base] ?? base;
}

/// Every text fastlane publishes to Play, one per field per language directory.
List<ListingText> readPlayTree(Directory root) {
  return _readTree(
    root,
    localePattern: playLocaleDirectory,
    fieldFiles: [...playListingFiles, '$changelogsDirectory/'],
    skipUnmatchedDirectories: false,
  );
}

/// Every field file the Windows Store publish reads, one per language directory.
List<ListingText> readMsstoreTree(Directory root) => _readTree(
      root,
      localePattern: msstoreLocaleDirectory,
      fieldFiles: msstoreListingFiles,
      skipUnmatchedDirectories: true,
    );

List<ListingText> _readTree(
  Directory root, {
  required RegExp localePattern,
  required List<String> fieldFiles,
  required bool skipUnmatchedDirectories,
}) {
  final texts = <ListingText>[];
  if (!root.existsSync()) return texts;
  final directories = root.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final directory in directories) {
    final name = _baseName(directory.path);
    if (name.startsWith('.')) continue;
    final language = languageForLocaleDirectory(name, localePattern);
    if (language == null) {
      // fastlane publishes a directory whatever it is named, so a stray one is
      // the Play tree's problem to report; `msstore` only reads dashed locales.
      if (skipUnmatchedDirectories) continue;
      for (final entry in _listingFiles(directory, fieldFiles)) {
        texts.add(
          ListingText(
            path: _relative(entry.path, root),
            language: name,
            body: entry.readAsStringSync(),
          ),
        );
      }
      continue;
    }
    for (final entry in _listingFiles(directory, fieldFiles)) {
      texts.add(
        ListingText(
          path: _relative(entry.path, root),
          language: language,
          body: entry.readAsStringSync(),
        ),
      );
    }
  }
  return texts;
}

List<File> _listingFiles(Directory locale, List<String> fieldFiles) {
  final files = <File>[];
  for (final name in fieldFiles) {
    if (name.endsWith('/')) {
      final dir = Directory('${locale.path}${Platform.pathSeparator}$name');
      if (!dir.existsSync()) continue;
      final notes = dir.listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      files.addAll(notes.where((note) => note.path.endsWith('.txt')));
      continue;
    }
    final file = File('${locale.path}${Platform.pathSeparator}$name');
    if (file.existsSync()) files.add(file);
  }
  return files;
}

/// Each sentence of every published text.
///
/// A blank line ends a paragraph, so a sentence wrapped across several lines of
/// a store description is still judged as one sentence. An HTML file is judged
/// line by line, because that is how the landing page is written: its markup
/// puts a claim and its qualifier on one line, and a blank line there is a layout
/// break rather than the end of a thought.
List<ClaimSentence> splitIntoSentences(List<ListingText> texts) {
  final sentences = <ClaimSentence>[];
  for (final text in texts) {
    final byLine = text.path.endsWith('.html');
    final lines = text.body.replaceAll('\r\n', '\n').split('\n');
    final run = <String>[];
    var runStart = 1;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        _addRun(sentences, text, run, runStart);
        run.clear();
        continue;
      }
      if (run.isEmpty) runStart = i + 1;
      run.add(line);
      if (byLine) {
        _addRun(sentences, text, run, runStart);
        run.clear();
      }
    }
    _addRun(sentences, text, run, runStart);
  }
  return sentences;
}

void _addRun(
  List<ClaimSentence> out,
  ListingText text,
  List<String> lines,
  int runStart,
) {
  if (lines.isEmpty) return;
  for (final sentence in _sentences(lines.join(' '))) {
    // A sentence is judged in its whole paragraph, so a finding names the first
    // line of that paragraph rather than the line its words happen to wrap onto.
    out.add(
      ClaimSentence(
        path: text.path,
        language: text.language,
        line: runStart,
        text: sentence,
      ),
    );
  }
}

/// The sentences of one paragraph: it ends at `.`, `!` or `?` when the next
/// character is a space or the paragraph is over, which leaves `v1.6.2` and a
/// URL alone.
List<String> _sentences(String paragraph) {
  final out = <String>[];
  final collapsed = paragraph.replaceAll(RegExp(r'\s+'), ' ');
  var start = 0;
  for (var i = 0; i < collapsed.length; i++) {
    if (!'.!?'.contains(collapsed[i])) continue;
    if (i + 1 < collapsed.length && collapsed[i + 1] != ' ') continue;
    final sentence = collapsed.substring(start, i + 1).trim();
    if (sentence.isNotEmpty) out.add(sentence);
    start = i + 1;
  }
  final rest = collapsed.substring(start).trim();
  if (rest.isNotEmpty) out.add(rest);
  return out;
}

/// Whether [needle] occurs in [text] as its own word, so "tracker" is not found
/// by "tracking" and "various" is not found by "ios". An inflected form is a
/// separate entry in [claimsByLanguage] because a glued letter ends the word.
bool containsWholeWord(String text, String needle) =>
    _wholeWord(needle).hasMatch(text);

final Map<String, RegExp> _wholeWordCache = {};

RegExp _wholeWord(String needle) => _wholeWordCache.putIfAbsent(
      needle,
      () => RegExp(
        '(?:^|[^\\p{L}\\p{N}])${_escape(needle)}(?:[^\\p{L}\\p{N}]|\$)',
        unicode: true,
      ),
    );

String _escape(String text) => text.replaceAllMapped(
      RegExp(r'[.*+?^${}()|[\]\\]'),
      (match) => '\\${match[0]}',
    );

/// Every claim stated without naming the build or channel it is true of.
List<String> findUnqualifiedClaims(List<ClaimSentence> sentences) {
  final violations = <String>[];
  final unchecked = <String, String>{};
  for (final sentence in sentences) {
    final claims = claimsByLanguage[sentence.language];
    if (claims == null) {
      unchecked.putIfAbsent(sentence.language, () => sentence.path);
      continue;
    }
    final lower = sentence.text.toLowerCase();
    for (final claim in claims) {
      if (!containsWholeWord(lower, claim)) continue;
      if (channelNames.any((channel) => containsWholeWord(lower, channel))) {
        break;
      }
      violations.add(
        '${sentence.path}:${sentence.line} claims "$claim" without naming a '
        'build or channel:\n      ${sentence.text}',
      );
      break;
    }
  }
  unchecked.forEach((language, path) {
    violations.add(
      '$language has no entry in claimsByLanguage, so copy in it goes unchecked '
      '($path). Add the ad, tracking and telemetry spellings to '
      'scripts/check_store_claims.dart.',
    );
  });
  return violations;
}

String _baseName(String path) => path.split(Platform.pathSeparator).last;

String _relative(String path, Directory root) => path
    .substring(root.path.length + 1)
    .replaceAll(Platform.pathSeparator, '/');

/// The published copy in this checkout: both store trees plus the documents.
List<ListingText> readPublishedCopy({
  String playTree = playMetadataDirectory,
  String msstoreTree = msstoreDirectory,
  List<String> documents = documentFiles,
}) =>
    [
      ...readPlayTree(Directory(playTree)),
      ...readMsstoreTree(Directory(msstoreTree)),
      for (final document in documents)
        if (File(document).existsSync())
          ListingText(
            path: document,
            language: 'en',
            body: File(document).readAsStringSync(),
          ),
    ];

void main(List<String> args) {
  var playTree = playMetadataDirectory;
  var msstoreTree = msstoreDirectory;
  final documents = [...documentFiles];
  for (var i = 0; i < args.length; i++) {
    final flag = args[i];
    switch (flag) {
      case '--check':
        break;
      case '--play-tree':
      case '--msstore-tree':
      case '--document':
        if (++i >= args.length) {
          stderr.writeln('$flag needs a value');
          exitCode = 64;
          return;
        }
        switch (flag) {
          case '--play-tree':
            playTree = args[i];
          case '--msstore-tree':
            msstoreTree = args[i];
          default:
            documents.add(args[i]);
        }
      default:
        stderr.writeln(
          'usage: dart run scripts/check_store_claims.dart [--check] '
          '[--play-tree <dir>] [--msstore-tree <dir>] [--document <file>]',
        );
        exitCode = 64;
        return;
    }
  }

  final texts = readPublishedCopy(
    playTree: playTree,
    msstoreTree: msstoreTree,
    documents: documents,
  );
  if (texts.isEmpty) {
    stderr.writeln('no published copy found under $playTree or $msstoreTree');
    exitCode = 1;
    return;
  }

  final violations = findUnqualifiedClaims(splitIntoSentences(texts));
  if (violations.isEmpty) {
    final languages = texts.map((text) => text.language).toSet().toList()
      ..sort();
    stdout.writeln(
      '${texts.length} published texts in ${languages.join(', ')} carry no '
      'unqualified ad, tracking or telemetry claim.',
    );
    return;
  }
  stderr.writeln('published copy makes a claim no build can promise:');
  for (final violation in violations) {
    stderr.writeln('    $violation');
  }
  exitCode = 1;
}
