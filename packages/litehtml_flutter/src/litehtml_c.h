// API C minima sopra litehtml.
// Tutte le callback sono sincrone e chiamate sul thread che chiama
// lh_create/lh_render/lh_draw. L'HTML non è fidato: vedi i limiti sotto e le
// patch "PATCH postino" in third_party/litehtml/VERSION.
#ifndef LITEHTML_C_H
#define LITEHTML_C_H

#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#define LH_EXPORT __declspec(dllexport)
#else
#define LH_EXPORT __attribute__((visibility("default")))
#endif

// Byte massimi dell'HTML accettato da lh_create.
#define LH_MAX_HTML_BYTES (4 * 1024 * 1024)

// Esito di lh_create.
#define LH_OK 0
#define LH_TOO_LARGE 1 // html oltre LH_MAX_HTML_BYTES
#define LH_FAILED 2    // litehtml ha lanciato un'eccezione
#define LH_TOO_DEEP 3  // html oltre kGumboMaxOpenElements elementi aperti

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  float x, y, w, h;
} lh_rect;

typedef struct {
  float width;
  int32_t style;  // litehtml::border_style
  uint32_t color; // ARGB
} lh_border;

typedef struct {
  lh_rect box;
  lh_border left, top, right, bottom;
  float radii[8]; // tl x,y, tr x,y, br x,y, bl x,y
} lh_borders;

typedef struct {
  float height, ascent, descent, x_height, ch_width;
} lh_font_metrics;

typedef struct {
  // Misura (servono al layout).
  int64_t (*create_font)(const char *family, float size, int32_t weight,
                         int32_t italic, int32_t decoration,
                         lh_font_metrics *out);
  float (*text_width)(const char *text, int64_t font);
  // Disegno.
  void (*draw_text)(const char *text, int64_t font, uint32_t color,
                    const lh_rect *pos);
  void (*fill_rect)(const lh_rect *rect, const lh_rect *clip,
                    const float *radii, uint32_t color);
  void (*draw_borders)(const lh_borders *borders);
  // `src` di un <img>; rect = riquadro del contenuto.
  void (*draw_image)(const char *src, const lh_rect *rect, const float *radii);
  void (*set_clip)(const lh_rect *rect, const float *radii);
  void (*del_clip)(void);
  // Una volta per `src` non vuoto di un <img>, dentro lh_create: il chiamante
  // lo carica e poi chiama lh_set_image_size.
  void (*load_image)(const char *src);
} lh_callbacks;

// Contenuto per selezione e Semantics (lh_export).
#define LH_SEP_SPACE 0    // spazio tolto a inizio o fine riga
#define LH_SEP_LINE 1     // <br>, a capo di <pre>, confine di blocco o cella
#define LH_NODE_HEADING 0 // h1..h6: level 1..6
#define LH_NODE_LINK 1    // <a href>: attr = href
#define LH_NODE_IMAGE 2   // <img>: attr = alt ("" se assente), level 1 se senza src

typedef struct {
  // Una parola o una run di spazi (" ") visibile, col font e il box di
  // draw_text.
  void (*text)(const char *text, int64_t font, const lh_rect *pos);
  // Separatore nel testo (LH_SEP_*); più separatori di fila si sommano.
  void (*separator)(int32_t kind);
  // Apre un nodo (LH_NODE_*) col suo box; close lo chiude dopo i figli.
  void (*open)(int32_t kind, int32_t level, const char *attr,
               const lh_rect *box);
  void (*close)(void);
} lh_export_callbacks;

typedef struct lh_doc lh_doc;

// Crea il documento (parse + stili) da `length` byte UTF-8 per una viewport
// larga `width`. Restituisce NULL e scrive l'esito in `status`.
LH_EXPORT lh_doc *lh_create(const char *html, size_t length, float width,
                            const lh_callbacks *cb, int32_t *status);
// Layout alla larghezza data; restituisce l'altezza del contenuto, -1 se il
// layout fallisce (eccezione o budget di lavoro esaurito). Dopo un errore il
// documento resta inutilizzabile: lh_render restituisce -1, lh_draw non fa
// nulla.
LH_EXPORT float lh_render(lh_doc *doc, float width);
// Emette i comandi di disegno per tutto il documento.
LH_EXPORT void lh_draw(lh_doc *doc);
// Emette testo e nodi dell'ultimo layout in ordine di documento; non fa nulla
// se il documento è fallito.
LH_EXPORT void lh_export(lh_doc *doc, const lh_export_callbacks *cb);
LH_EXPORT void lh_destroy(lh_doc *doc);
// Dimensione naturale di un'immagine caricata, in px CSS. Restituisce 1 se è
// cambiata (serve un nuovo lh_render), 0 altrimenti.
LH_EXPORT int32_t lh_set_image_size(lh_doc *doc, const char *src, float width,
                                    float height);
// href del link (<a href>) sotto il punto (x, y) dell'ultimo layout, NULL se
// non c'è. La stringa vive nel DOM: valida fino al prossimo lh_* sul documento.
LH_EXPORT const char *lh_link_at(lh_doc *doc, float x, float y);

#ifdef __cplusplus
}
#endif

#endif
