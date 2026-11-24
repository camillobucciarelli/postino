// document_container che inoltra misura e disegno alle callback Dart.
#include "litehtml_c.h"

#include <litehtml.h>

#include <cctype>
#include <cstdlib>
#include <map>
#include <string>

using namespace litehtml;

namespace {

constexpr float kViewportHeight = 800;

// Chrome rende <center> e align=center con `-webkit-center`: centra anche i
// blocchi figli (tabelle-bottone di MJML) e una <table> non lo eredita (torna a
// `start`). litehtml usa `text-align:center` semplice. Approssimazione in CSS.
// ponytail: copre i figli diretti; il vero `-webkit-center` va nel motore.
constexpr const char *kUserCss =
    "center table, div[align=center] table { text-align: left; }"
    "center > table, [align=center] > table { margin-left: auto; "
    "margin-right: auto; }";

lh_rect to_rect(const position &p) { return {p.x, p.y, p.width, p.height}; }

uint32_t to_argb(const web_color &c) {
  return (uint32_t(c.alpha) << 24) | (uint32_t(c.red) << 16) |
         (uint32_t(c.green) << 8) | uint32_t(c.blue);
}

void to_radii(const border_radiuses &r, float out[8]) {
  out[0] = r.top_left_x;
  out[1] = r.top_left_y;
  out[2] = r.top_right_x;
  out[3] = r.top_right_y;
  out[4] = r.bottom_right_x;
  out[5] = r.bottom_right_y;
  out[6] = r.bottom_left_x;
  out[7] = r.bottom_left_y;
}

lh_border to_border(const border &b) {
  return {b.width, int32_t(b.style), to_argb(b.color)};
}

class container final : public document_container {
public:
  explicit container(const lh_callbacks &cb, float width)
      : cb_(cb), width(width) {}

  float width;

  uint_ptr create_font(const font_description &d, const document *,
                       font_metrics *fm) override {
    lh_font_metrics m{};
    auto id = cb_.create_font(d.family.c_str(), d.size, d.weight,
                              d.style == font_style_italic, d.decoration_line,
                              &m);
    fm->font_size = d.size;
    fm->height = m.height;
    fm->ascent = m.ascent;
    fm->descent = m.descent;
    fm->x_height = m.x_height;
    fm->ch_width = m.ch_width;
    // Come il container cairo: gli spazi si disegnano solo se servono
    // (sottolineatura continua, corsivo).
    fm->draw_spaces = d.style == font_style_italic || d.decoration_line != 0;
    fm->sub_shift = d.size / 5;
    fm->super_shift = d.size / 3;
    return uint_ptr(id);
  }

  // ponytail: i font vivono nel documento Dart e muoiono con lui.
  void delete_font(uint_ptr) override {}

  pixel_t text_width(const char *text, uint_ptr font) override {
    return cb_.text_width(text, int64_t(font));
  }

  void draw_text(uint_ptr, const char *text, uint_ptr font, web_color color,
                 const position &pos) override {
    auto r = to_rect(pos);
    cb_.draw_text(text, int64_t(font), to_argb(color), &r);
  }

  pixel_t pt_to_px(float pt) const override { return pt * 96 / 72; }
  pixel_t get_default_font_size() const override { return 16; }
  // Come il default di Chrome.
  const char *get_default_font_name() const override {
    return "Times New Roman";
  }

  void draw_list_marker(uint_ptr, const list_marker &m) override {
    if (m.marker_type == list_style_type_none) return;
    auto r = to_rect(m.pos);
    float radii[8] = {};
    if (m.marker_type != list_style_type_square) {
      for (auto &v : radii) v = m.pos.width / 2;
    }
    cb_.fill_rect(&r, &r, radii, to_argb(m.color));
  }

  // Niente rete: le immagini non si caricano mai.
  void load_image(const char *, const char *, bool) override {}

  // Dimensione "intrinseca" di un <img> = attributi width/height se entrambi
  // numerici, come il rapporto d'aspetto che il browser ricava dagli attributi
  // prima del caricamento (serve con `height:auto`). Altrimenti 0x0.
  // ponytail: chiave = src; due <img> con lo stesso src e attributi diversi
  // prendono il primo.
  void collect_images(const element::ptr &el) {
    if (std::string(el->get_tagName()) == "img") {
      float w = std::atof(el->get_attr("width", "0"));
      float h = std::atof(el->get_attr("height", "0"));
      img_sizes_.emplace(el->get_attr("src", ""), size(w > 0 && h > 0 ? w : 0,
                                                       w > 0 && h > 0 ? h : 0));
    }
    for (auto &child : el->children()) collect_images(child);
  }

  void get_image_size(const char *src, const char *, size &sz) override {
    auto it = img_sizes_.find(src);
    sz = it == img_sizes_.end() ? size(0, 0) : it->second;
  }

  // Solo gli <img> diventano rettangoli grigi; gli sfondi immagine no.
  void draw_image(uint_ptr, const background_layer &layer,
                  const std::string &url, const std::string &) override {
    if (img_sizes_.count(url) == 0) return;
    auto r = to_rect(layer.border_box);
    float radii[8];
    to_radii(layer.border_radius, radii);
    cb_.draw_image(&r, radii);
  }

  void draw_solid_fill(uint_ptr, const background_layer &layer,
                       const web_color &color) override {
    fill(layer, color);
  }
  // ponytail: gradienti = primo colore; Canvas.drawRect con Gradient se serve.
  void draw_linear_gradient(
      uint_ptr, const background_layer &layer,
      const background_layer::linear_gradient &g) override {
    if (!g.color_points.empty()) fill(layer, g.color_points.front().color);
  }
  void draw_radial_gradient(
      uint_ptr, const background_layer &layer,
      const background_layer::radial_gradient &g) override {
    if (!g.color_points.empty()) fill(layer, g.color_points.front().color);
  }
  void draw_conic_gradient(uint_ptr, const background_layer &layer,
                           const background_layer::conic_gradient &g) override {
    if (!g.color_points.empty()) fill(layer, g.color_points.front().color);
  }

  void draw_borders(uint_ptr, const borders &b, const position &pos,
                    bool) override {
    lh_borders out{to_rect(pos), to_border(b.left), to_border(b.top),
                   to_border(b.right), to_border(b.bottom), {}};
    to_radii(b.radius, out.radii);
    cb_.draw_borders(&out);
  }

  void set_caption(const char *) override {}
  void set_base_url(const char *) override {}
  void link(const std::shared_ptr<document> &, const element::ptr &) override {}
  void on_anchor_click(const char *, const element::ptr &) override {}
  void on_mouse_event(const element::ptr &, mouse_event) override {}
  void set_cursor(const char *) override {}

  // ponytail: solo ASCII; per Unicode serve una callback Dart.
  void transform_text(string &text, text_transform tt) override {
    if (tt == text_transform_uppercase) {
      for (auto &c : text) c = char(std::toupper((unsigned char)c));
    } else if (tt == text_transform_lowercase) {
      for (auto &c : text) c = char(std::tolower((unsigned char)c));
    } else if (tt == text_transform_capitalize && !text.empty()) {
      text[0] = char(std::toupper((unsigned char)text[0]));
    }
  }

  // Niente rete (ADR 0007): <link> e @import ignorati.
  void import_css(string &, const string &, string &) override {}

  void set_clip(const position &pos, const border_radiuses &r) override {
    auto rect = to_rect(pos);
    float radii[8];
    to_radii(r, radii);
    cb_.set_clip(&rect, radii);
  }
  void del_clip() override { cb_.del_clip(); }

  void get_viewport(position &viewport) const override {
    viewport = {0, 0, width, kViewportHeight};
  }

  element::ptr create_element(const char *, const string_map &,
                              const std::shared_ptr<document> &) override {
    return nullptr;
  }

  void get_media_features(media_features &media) const override {
    media.type = media_type_screen;
    media.width = width;
    media.height = kViewportHeight;
    media.device_width = width;
    media.device_height = kViewportHeight;
    media.color = 8;
    media.monochrome = 0;
    media.color_index = 256;
    media.resolution = 96;
  }

  void get_language(string &language, string &culture) const override {
    language = "it";
    culture = "";
  }

private:
  void fill(const background_layer &layer, const web_color &color) {
    auto r = to_rect(layer.border_box);
    auto clip = to_rect(layer.clip_box);
    float radii[8];
    to_radii(layer.border_radius, radii);
    cb_.fill_rect(&r, &clip, radii, to_argb(color));
  }

  lh_callbacks cb_;
  std::map<std::string, size> img_sizes_;
};

} // namespace

struct lh_doc {
  container cont;
  document::ptr doc;
};

lh_doc *lh_create(const char *html, float width, const lh_callbacks *cb) {
  auto *d = new lh_doc{container(*cb, width), nullptr};
  try {
    d->doc = document::createFromString(
        estring(html, encoding::utf_8), &d->cont, master_css, kUserCss);
    if (d->doc) d->cont.collect_images(d->doc->root());
  } catch (...) {
    d->doc = nullptr;
  }
  if (!d->doc) {
    delete d;
    return nullptr;
  }
  return d;
}

float lh_render(lh_doc *d, float width) {
  try {
    if (d->cont.width != width) {
      d->cont.width = width;
      d->doc->media_changed();
    }
    d->doc->render(width);
    return d->doc->height();
  } catch (...) {
    return -1;
  }
}

void lh_draw(lh_doc *d) {
  position clip(0, 0, 1e7f, 1e7f);
  try {
    d->doc->draw(0, 0, 0, &clip);
  } catch (...) {
  }
}

void lh_destroy(lh_doc *d) { delete d; }
