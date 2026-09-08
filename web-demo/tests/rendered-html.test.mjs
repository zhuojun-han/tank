import assert from "node:assert/strict";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("http://localhost/", {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

test("renders the water-quality demo shell", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<html[^>]*lang="zh-CN"/i);
  assert.match(html, /<title>澜礁 · 海缸水质助手 Demo<\/title>/i);
  assert.match(html, /澜礁海缸助手网页版演示/);
  assert.match(html, /今日待办/);
  assert.match(html, /所有参数变化趋势/);
  assert.match(html, /调整后复测，观察生物状态/);
  assert.doesNotMatch(html, /Your site is taking shape|Building your site/i);
});

test("exposes the main prototype navigation and settings entry", async () => {
  const response = await render();
  const html = await response.text();

  for (const label of ["首页", "检测", "趋势", "任务"]) {
    assert.match(html, new RegExp(`>${label}<`));
  }

  assert.match(html, /aria-label="打开设置"/);
  assert.match(html, /当前海缸/);
});
