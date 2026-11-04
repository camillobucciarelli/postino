"""Tagli di troncamento esatti per l'app (flutter_edge_ai non espone il tokenizer del .litertlm).

Usa il tokenizer ufficiale di google/embeddinggemma-2 (tokenizer.json, stesso SentencePiece Gemma del bundle,
verificato nell'app contro il conteggio esatto del motore) e scrive, per ogni email e maxTokens, quanti code point
del testo `emailText` tenere perché `<bos> task: classification | query: <testo> <eos>` stia in maxTokens.

  curl -sSLo /tmp/tokenizer.json https://huggingface.co/google/embeddinggemma-2/resolve/main/tokenizer.json
  uv run --no-project --with tokenizers python tool/token_cuts.py /tmp/tokenizer.json
"""
import json
import sys
from pathlib import Path

from tokenizers import Tokenizer

PREFIX = 'task: classification | query: '
here = Path(__file__).resolve().parent.parent
tok = Tokenizer.from_file(sys.argv[1])
data = json.loads((here / 'assets/emails.json').read_text())


def count(text):  # bos + eos inclusi, come li aggiunge il motore
    return len(tok.encode(PREFIX + text).ids)


cuts, full = {}, {}
for e in data['emails']:
    text = f"Oggetto: {e['subject']}\nDa: {e['from']}\n\n{e['body']}"  # = emailText() di eval/lib/embedding_text.dart
    full[e['id']] = count(text)
    for max_tokens in (256, 512):
        n = len(text)
        if full[e['id']] > max_tokens:
            enc = tok.encode(PREFIX + text, add_special_tokens=False)
            n = enc.offsets[max_tokens - 3][1] - len(PREFIX)  # max-2 token di contenuto
            while count(text[:n]) > max_tokens:  # un taglio può riunire i pezzi in modo diverso
                n -= 1
        cuts.setdefault(str(max_tokens), {})[e['id']] = n

# Controllo del tokenizer nell'app: l'email più lunga ripetuta supera 1024 e il motore riporta il conteggio esatto.
longest = max(data['emails'], key=lambda e: full[e['id']])
lt = f"Oggetto: {longest['subject']}\nDa: {longest['from']}\n\n{longest['body']}"
check = {'id': longest['id'], 'tokens': count(lt + '\n\n' + lt)}
(here / 'assets/token_cuts.json').write_text(json.dumps({'tokens': full, 'cuts': cuts, 'check': check}, indent=1))
for m in (256, 512):
    print(f'maxTokens {m}: {sum(v > m for v in full.values())}/{len(full)} email troncate')
print('token (prefisso incluso) min/mediana/max:', min(full.values()), sorted(full.values())[40], max(full.values()))
