// Shows a placeholder when a post's thumbnail fails to load, instead of the browser's broken image icon
const MissingThumbnails = {};

MissingThumbnails.SELECTOR = ".post-preview img, .post-thumbnail img";
MissingThumbnails.IMAGE = "/images/missing-preview.png";

MissingThumbnails.replace = function (img) {
  // the placeholder failing too would loop forever
  if (img.dataset.missing) return;
  img.dataset.missing = "true";

  // a <picture>'s sources win over the img's src, so they have to go
  img.closest("picture")?.querySelectorAll("source").forEach(source => source.remove());
  // the size of the image that didn't load would stretch the placeholder
  img.removeAttribute("width");
  img.removeAttribute("height");
  img.removeAttribute("srcset");
  img.src = MissingThumbnails.IMAGE;
  img.classList.add("missing-thumbnail");
};

MissingThumbnails.isBroken = function (img) {
  return img.complete && img.naturalWidth === 0 && img.getAttribute("src");
};

// error events don't bubble, so they're caught on the way down instead
document.addEventListener("error", (event) => {
  const img = event.target;
  if (img instanceof HTMLImageElement && img.matches(MissingThumbnails.SELECTOR))
    MissingThumbnails.replace(img);
}, true);

// images that already failed before this ran
$(function () {
  for (const img of document.querySelectorAll(MissingThumbnails.SELECTOR)) {
    if (MissingThumbnails.isBroken(img))
      MissingThumbnails.replace(img);
  }
});

export default MissingThumbnails;
