// Esporta testo e struttura dell'ultimo layout per selezione e Semantics.
#ifndef LITEHTML_EXPORT_H
#define LITEHTML_EXPORT_H

#include "litehtml_c.h"

#include <litehtml.h>

// Visita l'albero di render in ordine di documento e chiama `cb` (vedi
// lh_export in litehtml_c.h).
void export_content(const litehtml::document::ptr &doc,
                    const lh_export_callbacks &cb);

#endif
