import 'model_descriptor.dart';

/// EmbeddingGemma-2 text 270m as `.litertlm` (ADR 0015): the most accurate, but LiteRT-LM embeds only on the CPU
/// of arm64 Apple and Android devices. URL pinned to the commit; size and SHA-256 checked on 2026-11-05.
final embeddingGemmaLiteRt = ModelDescriptor(
  id: 'embeddinggemma-2-270m-litertlm',
  url: Uri.parse(
    'https://huggingface.co/litert-community/embeddinggemma-2-text-270m-litert-lm/resolve/'
    '9be6e8b90982095dc05c2bd162e4b954ee4dbac7/embeddinggemma-2-text-270m.litertlm',
  ),
  sizeBytes: 164626432,
  sha256: '2d079ee2f6f066b1f368e8d7c819f55214eaef1d0513b312321901f30ab286fb',
  fileName: 'embeddinggemma-2-text-270m.litertlm',
);

/// EmbeddingGemma-2 270m as GGUF Q8_0 (ADR 0015), from ggml-org, the llama.cpp organisation: everywhere else.
/// Its vectors are not comparable with the `.litertlm` ones, hence another id.
final embeddingGemmaGguf = ModelDescriptor(
  id: 'embeddinggemma-2-270m-gguf-q8_0',
  url: Uri.parse(
    'https://huggingface.co/ggml-org/embeddinggemma-2-GGUF/resolve/'
    '6ea3e3a309d12a4779cfda98b8c19800d2d5da71/embeddinggemma-2-Q8_0.gguf',
  ),
  sizeBytes: 309855456,
  sha256: '2188ac1deca4b77dffefd603c2776a9d76d9d74ec01841392982ebb840b09135',
  fileName: 'embeddinggemma-2-Q8_0.gguf',
);

/// The embedding model for [os] (as `Platform.operatingSystem`) on [architecture] (as the second half of
/// `Abi.current()`, e.g. `arm64`, `x64`): `.litertlm` on macOS, iOS and Android arm64, GGUF everywhere else,
/// macOS Intel or under Rosetta and Android x86_64 included.
ModelDescriptor embeddingModelFor(String os, String architecture) =>
    architecture == 'arm64' && const {'macos', 'ios', 'android'}.contains(os)
    ? embeddingGemmaLiteRt
    : embeddingGemmaGguf;
