(function () {
  function wrapUrl(value) {
    if (!value) return "";
    if (value.indexOf("url(") === 0) return value;
    return 'url("' + value.replace(/^['"]|['"]$/g, "") + '")';
  }

  function isPlaceholder(src) {
    return !src || src.indexOf("data:image/") === 0;
  }

  function hydrateImage(img) {
    var sizes = img.getAttribute("data-sizes");
    var srcset = img.getAttribute("data-srcset");
    var src = img.getAttribute("data-src");

    if (sizes && !img.getAttribute("sizes")) {
      img.setAttribute("sizes", sizes);
    }

    if (srcset && img.getAttribute("srcset") !== srcset) {
      img.setAttribute("srcset", srcset);
    }

    if (src && isPlaceholder(img.getAttribute("src"))) {
      img.setAttribute("src", src);
    }
  }

  function hydrateSource(source) {
    var srcset = source.getAttribute("data-srcset");
    var sizes = source.getAttribute("data-sizes");

    if (srcset && source.getAttribute("srcset") !== srcset) {
      source.setAttribute("srcset", srcset);
    }

    if (sizes && !source.getAttribute("sizes")) {
      source.setAttribute("sizes", sizes);
    }
  }

  function hydrateIframe(frame) {
    var src = frame.getAttribute("data-src");
    if (src && !frame.getAttribute("src")) {
      frame.setAttribute("src", src);
    }
  }

  function hydrateVideo(video) {
    var poster = video.getAttribute("data-poster");
    var src = video.getAttribute("data-src");

    if (poster && !video.getAttribute("poster")) {
      video.setAttribute("poster", poster);
    }

    if (src && !video.getAttribute("src")) {
      video.setAttribute("src", src);
    }
  }

  function hydrateBackground(node) {
    var directBackground = node.getAttribute("data-bg-hidpi") || node.getAttribute("data-bg");
    var layeredBackground = node.getAttribute("data-bg-multi-hidpi") || node.getAttribute("data-bg-multi");
    var thumbnail = node.getAttribute("data-thumbnail");
    var current = node.style.backgroundImage;

    if (current && current !== "none") {
      return;
    }

    if (layeredBackground) {
      node.style.backgroundImage = layeredBackground;
      return;
    }

    if (directBackground) {
      node.style.backgroundImage = wrapUrl(directBackground);
      return;
    }

    if (thumbnail) {
      node.style.backgroundImage = wrapUrl(thumbnail);
    }
  }

  function run() {
    document.querySelectorAll("img[data-src], img[data-srcset], img[data-sizes]").forEach(hydrateImage);
    document.querySelectorAll("source[data-srcset], source[data-sizes]").forEach(hydrateSource);
    document.querySelectorAll("iframe[data-src]").forEach(hydrateIframe);
    document.querySelectorAll("video[data-src], video[data-poster]").forEach(hydrateVideo);
    document
      .querySelectorAll("[data-bg], [data-bg-hidpi], [data-bg-multi], [data-bg-multi-hidpi], [data-thumbnail]")
      .forEach(hydrateBackground);

    if (document.body) {
      document.body.classList.add("litespeed_lazyloaded");
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", run, { once: true });
  } else {
    run();
  }

  if (typeof window.requestAnimationFrame === "function") {
    window.requestAnimationFrame(function () {
      window.requestAnimationFrame(run);
    });
  }

  window.addEventListener("load", run, { once: true });
  document.addEventListener("DOMContentLiteSpeedLoaded", run);

  setTimeout(run, 250);
  setTimeout(run, 1000);
  setTimeout(run, 2500);
})();
