const PostReplacementReject = {};

PostReplacementReject.init = function () {
  const input = $("#post_replacement_reason");
  let inputVal = input.val() + "";

  const buttons = $("a.rejection-reason-button")
    .on("click", (event) => {
      event.stopPropagation();
      event.preventDefault();

      const $button = $(event.target);
      if (!$button.is("a")) return;

      const text = $button.data("processed");
      input.val((index, current) => {
        current = current.trim();
        if ($button.hasClass("enabled")) {
          return current
            .replace(text, "");
        } else return (current ? current + " / " : "") + text;
      });
      input.trigger("input");
    })
    .on("e621:refresh", (event) => {
      const $button = $(event.target);
      const text = $button.data("text");

      $button.data("processed", text);
      $button.toggleClass("enabled", inputVal.indexOf(text) >= 0);
    })
    .each((index, element) => {
      const $button = $(element);
      $button.find("input[type=text]").on("input", () => {
        $button.trigger("e621:refresh");
      });
    });
  buttons.trigger("e621:refresh");

  input.on("input", () => {
    inputVal = input.val() + "";
    buttons.trigger("e621:refresh");
  });

  $("#rejection-reason-clear").on("click", () => {
    input.val("").trigger("input");
  });
};

$(function () {
  if ($("div#c-posts-replacements div#a-reject-with-reason").length) {
    Fennec.PostReplacementRejection.init();
  }
});

export default PostReplacementReject;
