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
};

void *run(void *arg) {
  auto *c = static_cast<test_case *>(arg);
  lh_callbacks cb{create_font, text_width, draw_text,  fill_rect,
                  draw_borders, draw_image, set_clip, del_clip};
  int32_t status = -1;
  lh_doc *doc = lh_create(c->html.data(), c->html.size(), 600, &cb, &status);
  if (doc) {
    lh_render(doc, 600);
    lh_draw(doc);
    lh_destroy(doc);
  }
  if (status != c->status) {
    fprintf(stderr, "%s: status %d, atteso %d\n", c->name, status, c->status);
    return arg;
  }
  printf("ok %s\n", c->name);
  return nullptr;
}

} // namespace

int main() {
  // Appena sotto il tetto del parser (512 elementi aperti) e oltre quello del DOM (128).
  test_case cases[] = {
      {"div", repeat("<div>", 510) + "x", LH_OK},
      {"float", repeat("<div style=\"float:left\">", 510) + "x", LH_OK},
      {"flex", repeat("<div style=\"display:flex\">", 510) + "x", LH_OK},
      {"ul", repeat("<ul><li>", 255) + "x", LH_OK},
      {"table", repeat("<table><tr><td>", 127) + "x", LH_OK},
      {"span", repeat("<span>", 510) + "x", LH_OK},
      {"css", "<style>" + repeat("@media screen{", 100000) + "</style>x", LH_OK},
      {"css-fn", "<p style=\"color:" + repeat("f(", 100000) + "\">x</p>", LH_OK},
      {"html-100k", repeat("<div>", 100000) + "x", LH_TOO_DEEP},
  };
  pthread_attr_t attr;
  pthread_attr_init(&attr);
  pthread_attr_setstacksize(&attr, kStackKB * 1024);
  int failed = 0;
  for (auto &c : cases) {
    pthread_t thread;
    void *result = nullptr;
    pthread_create(&thread, &attr, run, &c);
    pthread_join(thread, &result);
    failed += result != nullptr;
  }
  return failed;
}
