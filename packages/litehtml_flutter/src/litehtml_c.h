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
  void (*draw_image)(const lh_rect *rect, const float *radii);
  void (*set_clip)(const lh_rect *rect, const float *radii);
  void (*del_clip)(void);
} lh_callbacks;

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
LH_EXPORT void lh_destroy(lh_doc *doc);

#ifdef __cplusplus
}
#endif

#endif
