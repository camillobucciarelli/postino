/// Whole decimal megabytes, as model sizes are published: «310 MB».
String megabytes(int bytes) => '${bytes ~/ 1000000} MB';

/// The parts of «167 MB di 310 MB · 54%» (#107); the sentence around them is in i18n. Received MB and the
/// percentage round down, so neither reads full before the download is.
({String received, String total, int percent}) downloadProgress(int receivedBytes, int totalBytes) => (
  received: megabytes(receivedBytes),
  total: megabytes(totalBytes),
  percent: totalBytes <= 0 ? 0 : (receivedBytes * 100 ~/ totalBytes).clamp(0, 100),
);
