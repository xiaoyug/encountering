var params = new URLSearchParams(location.search);
var slug = params.get("e") || "mushenzhen-2026";
if (!/^[\w\u4e00-\u9fff-]{1,80}$/.test(slug) || slug === "mufriends-2026-11-06") slug = "mushenzhen-2026";
var link = document.getElementById("go");
if (link) link.href = "https://mufriends.mushenzhen.xyz/upload/?e=" + encodeURIComponent(slug);
if ("serviceWorker" in navigator) navigator.serviceWorker.register("./sw.js").catch(function () {});
