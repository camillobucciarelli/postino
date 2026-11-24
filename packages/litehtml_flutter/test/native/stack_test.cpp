// Il caso peggiore ammesso dai limiti di annidamento (PATCH postino) deve stare in uno stack
// piccolo: ogni caso gira in un thread con kStackKB di stack e callback finte. Uno stack
// overflow fa cadere il processo e quindi il test (lanciato da stack_test.sh).
#include "litehtml_c.h"

#include <pthread.h>

#include <cstdio>
#include <cstring>
#include <string>

namespace {

constexpr size_t kStackKB = 256;

int64_t create_font(const char *, float size, int32_t, int32_t, int32_t,
                    lh_font_metrics *m) {
  *m = {size * 1.2f, size, size * 0.2f, size / 2, size / 2};
  return 1;
}
float text_width(const char *text, int64_t) { return strlen(text) * 8.0f; }
void draw_text(const char *, int64_t, uint32_t, const lh_rect *) {}
void fill_rect(const lh_rect *, const lh_rect *, const float *, uint32_t) {}
void draw_borders(const lh_borders *) {}
void draw_image(const lh_rect *, const float *) {}
void set_clip(const lh_rect *, const float *) {}
void del_clip() {}

std::string repeat(const char *s, int n) {
  std::string r;
  for (int i = 0; i < n; i++) r += s;
  return r;
}

struct test_case {
  const char *name;
  std::string html;
  int32_t status; // atteso da lh_create
  bool layout_ok; // lh_render >= 0 (false: budget di layout esaurito)
};

void *run(void *arg) {
  auto *c = static_cast<test_case *>(arg);
  lh_callbacks cb{create_font, text_width, draw_text,  fill_rect,
                  draw_borders, draw_image, set_clip, del_clip};
  int32_t status = -1;
  lh_doc *doc = lh_create(c->html.data(), c->html.size(), 600, &cb, &status);
  bool layout_ok = false;
  if (doc) {
    layout_ok = lh_render(doc, 600) >= 0;
    lh_draw(doc);
    lh_destroy(doc);
  }
  if (status != c->status || (doc && layout_ok != c->layout_ok)) {
    fprintf(stderr, "%s: status %d layout %d, attesi %d %d\n", c->name, status,
            layout_ok, c->status, c->layout_ok);
    return arg;
  }
  printf("ok %s\n", c->name);
  return nullptr;
}

} // namespace

int main() {
  // Al tetto del DOM (128 livelli contando html e body): i casi più profondi ammessi.
  test_case cases[] = {
      {"div", repeat("<div>", 126) + "x", LH_OK, true},
      {"float", repeat("<div style=\"float:left\">", 126) + "x", LH_OK, true},
      {"flex", repeat("<div style=\"display:flex\">", 126) + "x", LH_OK, false},
      {"ul", repeat("<ul><li>", 63) + "x", LH_OK, true},
      {"table", repeat("<table><tr><td>", 31) + "x", LH_OK, false},
      {"span", repeat("<span>", 126) + "x", LH_OK, true},
      {"css", "<style>" + repeat("@media screen{", 100000) + "</style>x", LH_OK, true},
      {"css-fn", "<p style=\"color:" + repeat("f(", 100000) + "\">x</p>", LH_OK, true},
      {"dom-127", repeat("<div>", 127) + "x", LH_TOO_DEEP, false},
      {"html-100k", repeat("<div>", 100000) + "x", LH_TOO_DEEP, false},
  };
  pthread_attr_t attr;
  pthread_attr_init(&attr);
  pthread_attr_setstacksize(&attr, kStackKB * 1024);
  int failed = 0;
  for (auto &c : cases) {
    pthread_t thread;
    void *result = &c;
    if (pthread_create(&thread, &attr, run, &c) != 0 ||
        pthread_join(thread, &result) != 0) {
      fprintf(stderr, "%s: thread non avviato\n", c.name);
      return 1;
    }
    failed += result != nullptr;
  }
  return failed;
}
