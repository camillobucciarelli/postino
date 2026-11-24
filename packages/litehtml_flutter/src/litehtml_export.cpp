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

  // (x, y) = origine dei figli del padre, come in render_item::draw_children.
  // La ricorsione è limitata dalla profondità del DOM (kMaxDomDepth).
  void walk(const std::shared_ptr<render_item> &ri, float x, float y) {
    const auto &el = ri->src_el();
    // <br> e a capo di <pre>: line_box li marca "skip" come gli spazi a fine
    // riga, ma nel testo restano un a capo.
    if (el->is_break()) {
      if (el->css().get_display() != display_none) {
        cb_.separator(LH_SEP_LINE);
      }
      return;
    }
    if (!ri->is_visible()) {
      // Spazio tolto a inizio o fine riga: nel testo copiato resta uno spazio.
      if (el->is_white_space()) cb_.separator(LH_SEP_SPACE);
      return;
    }
    if (el->css().get_position() == element_position_fixed) x = y = 0;
    position pos = ri->pos();
    pos.x += x;
    pos.y += y;
    const bool block = !el->is_inline();
    if (block) cb_.separator(LH_SEP_LINE);

    if (el->is_text()) text(*el, pos);

    const char *tag = el->get_tagName();
    int kind = -1;
    int level = heading_level(tag);
    const char *attr = "";
    if (level != 0) {
      kind = LH_NODE_HEADING;
    } else if (std::strcmp(tag, "a") == 0 && el->get_attr("href")) {
      kind = LH_NODE_LINK;
      attr = el->get_attr("href");
    } else if (std::strcmp(tag, "img") == 0) {
      kind = LH_NODE_IMAGE;
      attr = el->get_attr("alt", "");
    }
    if (kind >= 0) {
      auto box = to_rect(pos);
      cb_.open(kind, level, attr, &box);
    }
    for (const auto &child : ri->children()) walk(child, pos.x, pos.y);
    if (kind >= 0) cb_.close();
    if (block) cb_.separator(LH_SEP_LINE);
  }

private:
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
  if (root) exporter(doc->container(), cb).walk(root, 0, 0);
}
