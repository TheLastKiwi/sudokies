/// Firebase Realtime Database configuration.
///
/// The project's Realtime Database URL (no trailing slash). While this is
/// empty the app works entirely from the bundled starter set and the offline
/// tool skips uploading.
const String firebaseDbUrl = 'https://sudokies-default-rtdb.firebaseio.com';

/// The project's Web API key (Firebase console → Project settings → General →
/// "Web API Key"), used for anonymous sign-in via the Identity Toolkit REST
/// API. This is a public identifier rather than a secret — it only identifies
/// the project, and the database rules are what actually control access. While
/// it is empty, history stays local-only.
const String firebaseApiKey = 'AIzaSyC5QyGTvgj-6dHjNdaYFyRJH6ps4H0QFck';

bool get firebaseConfigured => firebaseDbUrl.isNotEmpty;

/// Whether history can sync: needs both the database URL and the Web API key,
/// plus Anonymous sign-in enabled in the console.
bool get firebaseAuthConfigured =>
    firebaseConfigured && firebaseApiKey.isNotEmpty;
