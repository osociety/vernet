/// Every external listing the app points at, in one place.
///
/// The update checker, the support page and the updates page all link to the
/// same releases and stores. A package or product id copied into three files
/// is an id that drifts when the listing changes.
const String githubRepositoryUrl = 'https://github.com/osociety/vernet';
const String githubReleasesUrl = '$githubRepositoryUrl/releases';
const String githubLatestReleaseUrl = '$githubReleasesUrl/latest';

/// Newest stable release, as GitHub has already filtered out drafts and
/// pre-releases.
const String githubLatestReleaseApiUrl =
    'https://api.github.com/repos/osociety/vernet/releases/latest';

/// Newest release of any kind, which is what a beta tester is offered.
const String githubReleasesApiUrl =
    'https://api.github.com/repos/osociety/vernet/releases';

const String playStoreListingUrl =
    'https://play.google.com/store/apps/details?id=org.fsociety.vernet.store';

/// The page that moves a Play install onto the beta track.
const String playBetaOptInUrl =
    'https://play.google.com/apps/testing/org.fsociety.vernet.store';

const String microsoftStoreListingUrl =
    'https://apps.microsoft.com/detail/9N1170N3PHMM';
const String snapStoreListingUrl = 'https://snapcraft.io/vernet';
