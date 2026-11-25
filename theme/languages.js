// Links to the same page in the other languages, in the menu bar. English is at the site root,
// every translation under its own path (build.sh builds one site per po/*.po file).
(function () {
  const languages = [["en", "English"], ["zh-CN", "简体中文"]];
  const lang = document.documentElement.lang || "en";
  const here = new URL(location.href);
  const root = new URL(path_to_root, here);
  const page = here.pathname.slice(root.pathname.length) || "index.html";
  const site = lang === "en" ? root : new URL("../", root);
  const bar = document.querySelector(".right-buttons");
  if (!bar) return;
  const nav = document.createElement("span");
  nav.className = "sc-languages";
  for (const [code, name] of languages) {
    const item = document.createElement(code === lang ? "strong" : "a");
    item.textContent = name;
    item.lang = code;
    if (code !== lang) item.href = new URL((code === "en" ? "" : code + "/") + page, site).href;
    nav.append(item);
  }
  bar.prepend(nav);
})();
