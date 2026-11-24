import 'package:flutter/painting.dart';

/// L'`ImageProvider` di un `src`: `data:` dai suoi byte, `http(s)` dalla rete; altro (`cid:`, relativi, `file:`) null.
///
/// Quali `src` arrivano qui lo decide chi prepara l'HTML (le regole sulle immagini remote stanno nell'app).
ImageProvider? litehtmlImageProvider(String src) {
  final url = src.trim();
  final lower = url.toLowerCase();
  if (lower.startsWith('data:')) {
    try {
      final bytes = Uri.parse(url).data?.contentAsBytes();
      return bytes == null || bytes.isEmpty ? null : MemoryImage(bytes);
    } on FormatException {
      return null;
    }
  }
  if (lower.startsWith('http://') || lower.startsWith('https://')) return NetworkImage(url);
  return null;
}

/// Carica le immagini di un documento con la cache delle immagini di Flutter e le passa a `onImage` una alla volta.
///
/// Solo il primo fotogramma (una GIF animata resta ferma). Un errore lascia il rettangolo grigio, senza segnalarlo.
class LitehtmlImages(
  final ImageProvider? Function(String src) _provider,
  final void Function(String src, ImageInfo info) _onImage,
) {
  /// Gli stream ancora in attesa: uno a cui si è tolto l'ultimo listener è già liberato da Flutter.
  final _listening = <ImageStream, ImageStreamListener>{};
  final _infos = <ImageInfo>[];
  var _pending = 0;
  var _disposed = false;

  /// Nessun caricamento in corso: la `Picture` registrata adesso è completa.
  bool get settled => _pending == 0;

  /// Avvia il caricamento di [sources]; una risposta già in cache arriva a `onImage` prima del ritorno.
  void load(Iterable<String> sources) {
    for (final src in sources) {
      final provider = _provider(src);
      if (provider == null) continue;
      _pending++;
      final stream = provider.resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      void done() {
        _pending--;
        _listening.remove(stream);
        stream.removeListener(listener);
      }

      listener = ImageStreamListener((info, _) {
        done();
        if (_disposed) return info.dispose();
        _infos.add(info);
        _onImage(src, info);
      }, onError: (_, _) => done());
      _listening[stream] = listener;
      stream.addListener(listener);
    }
  }

  /// Smette di ascoltare e rilascia le immagini (una `Picture` già registrata tiene le sue).
  void dispose() {
    _disposed = true;
    for (final MapEntry(key: stream, value: listener) in _listening.entries.toList()) {
      stream.removeListener(listener);
    }
    _listening.clear();
    for (final info in _infos) {
      info.dispose();
    }
    _infos.clear();
  }
}
