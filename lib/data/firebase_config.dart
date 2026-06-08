/// Firebase Realtime Database configuration.
///
/// Paste your free project's Realtime Database URL here (no trailing slash),
/// e.g. `https://my-sudoku-app-default-rtdb.firebaseio.com`. While this is
/// empty the app works entirely from the bundled starter set and the offline
/// tool skips uploading.
const String firebaseDbUrl = '';

bool get firebaseConfigured => firebaseDbUrl.isNotEmpty;
