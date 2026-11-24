// Visita dell'albero di render per lh_export: stesse coordinate di draw_text.
#include "litehtml_export.h"

#include <render_item.h>

#include <cstring>
#include <string>

using namespace litehtml;

namespace {

int heading_level(const char *tag) {
  if (tag[0] == 'h' && tag[1] >= '1' && tag[1] <= '6' && tag[2] == 0) {
    return tag[1] - '0';
  }
  return 0;
}

lh_rect to_rect(const position &p) { return {p.x, p.y, p.width, p.height}; }

class exporter {
public:
  exporter(document_container *container, const lh_export_callbacks &cb)
      : container_(container), cb_(cb) {}

  // (x, y) = origine dei figli del padre, come in render_item::draw_children;
  // clip = area visibile lasciata dagli antenati con overflow non visible.
  // layer = livello di pittura ereditato (vedi paint_layer).
  // La ricorsione è limitata dalla profondità del DOM (kMaxDomDepth).
  void walk(const std::shared_ptr<render_item> &ri, float x, float y,
            position clip, int layer) {
    const auto &el = ri->src_el();
    // <br> e a capo di <pre>: line_box li marca "skip" come gli spazi a fine
    // riga, ma nel testo restano un a capo.
    if (el->is_break()) {
      if (el->css().get_display() != display_none) {
        cb_.separator(LH_SEP_BREAK);
      }
      return;
    }
    if (!ri->is_visible()) {
      // Spazio tolto a inizio o fine riga: nel testo copiato resta uno spazio.
      if (el->is_white_space()) cb_.separator(LH_SEP_SPACE);
      return;
    }
    if (el->css().get_position() == element_position_fixed) x = y = 0;
    layer = paint_layer(*el, layer);
    position pos = ri->pos();
    pos.x += x;
    pos.y += y;
    const bool block = !el->is_inline();
    if (block) cb_.separator(LH_SEP_LINE);

    // Testo tagliato da overflow (es. il "preheader" con max-height:0): non
    // si vede, quindi non si seleziona né si annuncia.
    if (el->is_text() && visible(pos, clip)) text(*el, pos);

    const char *tag = el->get_tagName();
    int kind = -1;
    int level = heading_level(tag);
    const char *attr = "";
    if (level != 0) {
      kind = LH_NODE_HEADING;
    } else if (std::strcmp(tag, "a") == 0 && el->get_attr("href")) {
      kind = LH_NODE_LINK;
      attr = el->get_attr("href");
    } else if (std::strcmp(tag, "img") == 0 && visible(pos, clip)) {
      kind = LH_NODE_IMAGE;
      attr = el->get_attr("alt", "");
      // 1: senza src (bloccata o cid:), il segnaposto.
      level = *el->get_attr("src", "") ? 0 : 1;
    }
    if (kind >= 0) {
      auto box = to_rect(pos);
      if (kind == LH_NODE_LINK) {
        // Area cliccabile di un'ancora a blocco o inline-block: tutto il
        // border box (padding di un bottone, spazio vuoto di un blocco). Un
        // <a> inline ha solo i box del suo testo e delle sue immagini.
        // Solo la parte che si vede: un'ancora dentro un antenato con
        // overflow (preheader con max-height:0) non deve coprire il testo
        // che segue né diventare una fermata di Tab invisibile.
        position area = pos;
        area += ri->get_paddings();
        area += ri->get_borders();
        area = clip.intersect(area);
        const bool shaped =
            block || el->css().get_display() == display_inline_block;
        box = shaped && area.width > 0 && area.height > 0
                  ? to_rect(area)
                  : lh_rect{0, 0, 0, 0};
        level = layer;
      }
      cb_.open(kind, level, attr, &box);
    }
    // Come draw_children: gli elementi non inline tagliano al content box.
    if (el->css().get_overflow() > overflow_visible &&
        el->css().get_display() != display_inline) {
      clip = clip.intersect(pos);
    }
    for (const auto &child : ri->children()) {
      walk(child, pos.x, pos.y, clip, layer);
    }
    if (kind >= 0) cb_.close();
    if (block) cb_.separator(LH_SEP_LINE);
  }

private:
  // Livello di pittura, come l'ordine di draw_stacking_context: un elemento
  // posizionato sta sopra il flusso normale del suo z-index, e z-index più
  // alti sopra quelli più bassi. A parità di livello dipinge sopra chi viene
  // dopo nel documento.
  // ponytail: un contesto di impilamento per tutto il documento; z-index
  // annidati in posizionati con z-index diversi si confrontano piatti.
  static int paint_layer(const element &el, int inherited) {
    if (!el.is_positioned()) return inherited;
    return el.css().get_z_index() * 2 + 1;
  }

  static bool visible(const position &box, const position &clip) {
    return clip.intersect(box).width > 0;
  }

  void text(const element &el, position pos) {
    std::string s;
    if (el.is_white_space()) {
      s = " "; // spazi collassati
    } else {
      el.get_text(s);
      // Il testo disegnato è quello trasformato (el_text::draw).
      if (el.css().get_text_transform() != text_transform_none) {
        container_->transform_text(s, el.css().get_text_transform());
      }
    }
    pos.round(); // come el_text::draw
    if (s.empty() || pos.width <= 0 || pos.height <= 0) return;
    auto r = to_rect(pos);
    cb_.text(s.c_str(), int64_t(el.css().get_font()), &r);
  }

  document_container *container_;
  const lh_export_callbacks &cb_;
};

} // namespace

void export_content(const document::ptr &doc, const lh_export_callbacks &cb) {
  auto root = doc->root_render();
  // Nessun taglio alla radice: tutta l'altezza del documento.
  if (root) {
    exporter(doc->container(), cb)
        .walk(root, 0, 0, position(-1e7f, -1e7f, 2e7f, 2e7f), 0);
  }
}
