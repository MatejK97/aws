// Visitor counter: counts each browser once per day. Scrapers that don't run
// JavaScript never reach the API; the WAF rate-limits the ones that do.
(function () {
  var el = document.getElementById("visits");
  if (!el || !window.fetch) return;

  var key = "matthomelab-last-visit";
  var today = new Date().toISOString().slice(0, 10);
  var last = null;
  try {
    last = localStorage.getItem(key);
  } catch (e) {}

  // First visit today adds one; later visits only read the count
  var path = last === today ? "/api/visitors" : "/api/visit";

  fetch(path, { cache: "no-store" })
    .then(function (r) {
      if (!r.ok) throw new Error(r.status);
      return r.json();
    })
    .then(function (data) {
      if (typeof data.visits !== "number") return;
      el.textContent = data.visits.toLocaleString("en");
      if (path === "/api/visit") {
        try {
          localStorage.setItem(key, today);
        } catch (e) {}
      }
    })
    .catch(function () {});
})();
