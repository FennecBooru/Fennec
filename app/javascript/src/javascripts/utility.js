import Shortcuts from "./shortcuts";

let Utility = {};

Utility.delay = function (milliseconds) {
  return new Promise(resolve => setTimeout(resolve, milliseconds));
};

Utility.meta = function (key) {
  return $("meta[name=" + key + "]").attr("content");
};

Utility.test_max_width = function (width) {
  if (!window.matchMedia) {
    return false;
  }
  var mq = window.matchMedia("(max-width: " + width + "px)");
  return mq.matches;
};

Utility.chunk = function (array, chunk_size) {
  const chunks = [];
  for (let i = 0; i < array.length; i += chunk_size) {
    chunks.push(array.slice(i, i + chunk_size));
  }

  return chunks;
};

Utility.notice_timeout_id = undefined;

Utility.notice = function (msg, permanent) {
  $("#notice").addClass("ui-state-highlight").removeClass("ui-state-error").fadeIn("fast").children("span").html(msg);

  if (Utility.notice_timeout_id !== undefined) {
    clearTimeout(Utility.notice_timeout_id);
  }
  if (!permanent) {
    Utility.notice_timeout_id = setTimeout(function () {
      $("#close-notice-link").click();
      Utility.notice_timeout_id = undefined;
    }, 6000);
  }
};

Utility.error = function (msg) {
  $("#notice").removeClass("ui-state-highlight").addClass("ui-state-error").fadeIn("fast").children("span").html(msg);

  if (Utility.notice_timeout_id !== undefined) {
    clearTimeout(Utility.notice_timeout_id);
  }
};

Utility.dialog = function (title, html) {
  const $dialog = $(html).dialog({
    title: title,
    width: 700,
    modal: true,
    close: function () {
      // Defer removing the dialog to avoid detaching the <form> tag before the
      // form is submitted (which would prevent the submission from going through).
      $(() => $dialog.dialog("destroy"));
    },
    buttons: {
      "Submit": function () {
        $dialog.find("form").submit();
      },
      "Cancel": function () {
        $dialog.dialog("close");
      },
    },
  });

  $dialog.find("form").on("submit.fennec", function () {
    $dialog.dialog("close");
  });
};

Utility.keydown = function (keys, namespace, handler) {
  console.log("Utility.keydown is deprecated and will be removed at a later date, use Shortcuts.keydown instead");
  Shortcuts.keydown(keys, namespace, handler);
};

Utility.is_subset = function (array, subarray) {
  var all = true;

  $.each(subarray, function (i, val) {
    if ($.inArray(val, array) === -1) {
      all = false;
    }
  });

  return all;
};

Utility.intersect = function (a, b) {
  a = a.slice(0).sort();
  b = b.slice(0).sort();
  var result = [];
  while (a.length > 0 && b.length > 0) {
    if (a[0] < b[0]) {
      a.shift();
    } else if (a[0] > b[0]) {
      b.shift();
    } else {
      result.push(a.shift());
      b.shift();
    }
  }
  return result;
};

Utility.regexp_escape = function (string) {
  return string.replace(/([.?*+^$[\]\\(){}|-])/g, "\\$1");
};

/**
 * @param string
 * @returns {URLSearchParams}
 */
Utility.get_query_params = function (string) {
  const url = new URL(string, window.location.origin);
  return new URLSearchParams(url.search);
};

/**
 * @param {string} string
 * @param {URLSearchParams} params
 * @returns {string}
 */
Utility.set_query_params = function (string, params) {
  const url = new URL(string, window.location.origin);
  url.search = params.toString();
  return url.toString();
};

Utility.printPage = function (url) {
  let iframe = document.createElement("iframe");
  iframe.style.display = "none";
  iframe.src = url;
  iframe.onload = () => iframe.contentWindow.print();
  document.body.appendChild(iframe);
};

Utility.copyToClipboard = async function (text, message = "Copied!") {
  try {
    await navigator.clipboard.writeText(text);
    Utility.notice(message);
  } catch {
    Utility.error("Couldn't copy to clipboard");
  }
};

$.fn.selectEnd = function () {
  return this.each(function () {
    this.focus();
    this.setSelectionRange(this.value.length, this.value.length);
  });
};

$(function () {
  $(window).on("fennec:notice", function (event, msg) {
    Utility.notice(msg);
  });

  $(window).on("fennec:error", function (event, msg) {
    Utility.error(msg);
  });
});

export default Utility;
