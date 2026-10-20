$(function () {
  $("#maintoggle").on("click.fennec", function (e) {
    e.preventDefault();
    $("#nav").toggle();
    $("#maintoggle-on").toggle();
    $("#maintoggle-off").toggle();
  });
});
