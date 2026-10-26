const CURSOR_CLASS = "shinx-cursor";
const CURSOR_STORAGE_KEY = "fennec.shinx-cursor";
const CURSOR_VALUE = "url(\"/images/shinx-cursor.png\") 24 24, auto";
const LINK_CURSOR_VALUE = "url(\"/images/strike-loaf-cursor.png\") 24 24, pointer";
const LOGO_VALUE = "url(\"/shinx.png\")";
const SECRET_SEQUENCE = [
  "ArrowUp",
  "ArrowUp",
  "ArrowDown",
  "ArrowDown",
  "ArrowLeft",
  "ArrowRight",
  "ArrowLeft",
  "ArrowRight",
  "b",
  "a",
];

function setCursorEnabled (enabled) {
  document.documentElement.style.setProperty("--shinx-cursor", CURSOR_VALUE);
  document.documentElement.style.setProperty("--strike-loaf-cursor", LINK_CURSOR_VALUE);
  document.documentElement.style.setProperty("--shinx-logo", LOGO_VALUE);
  document.documentElement.classList.toggle(CURSOR_CLASS, enabled);
  localStorage.setItem(CURSOR_STORAGE_KEY, enabled ? "on" : "off");
}

function isEditableTarget (target) {
  return target instanceof HTMLElement
    && (target.isContentEditable || ["INPUT", "SELECT", "TEXTAREA"].includes(target.tagName));
}

let sequenceIndex = 0;

function handleSecretKeydown (event) {
  if (event.ctrlKey || event.altKey || event.metaKey || event.isComposing || isEditableTarget(event.target)) {
    sequenceIndex = 0;
    return;
  }

  const key = event.key.length === 1 ? event.key.toLowerCase() : event.key;
  if (key === SECRET_SEQUENCE[sequenceIndex]) {
    sequenceIndex += 1;
  } else {
    sequenceIndex = key === SECRET_SEQUENCE[0] ? 1 : 0;
  }

  if (sequenceIndex === 0) return;

  event.preventDefault();
  event.stopImmediatePropagation();

  if (sequenceIndex === SECRET_SEQUENCE.length) {
    setCursorEnabled(!document.documentElement.classList.contains(CURSOR_CLASS));
    sequenceIndex = 0;
  }
}

window.addEventListener("keydown", handleSecretKeydown, true);

$(function () {
  setCursorEnabled(localStorage.getItem(CURSOR_STORAGE_KEY) === "on");

  $(document).on("click.fennec.secret-cursor", "#nav .logo, #nav .mobile-logo a", event => {
    if (!document.documentElement.classList.contains(CURSOR_CLASS)) return;

    event.preventDefault();
    setCursorEnabled(false);
  });
});
