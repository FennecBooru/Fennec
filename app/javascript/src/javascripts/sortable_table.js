import Utility from "./utility";

// The "Edit Order" and "Save" links for listing pages whose rows can be dragged into a new order.
// Rows need a data-id, and the page needs .edit-order-link and .save-order-link links.
class SortableTable {
  /**
   * @param {object} options
   * @param {string} options.table selector for the table
   * @param {string} options.url the reorder endpoint, which is sent [{ id, [key]: number }, ...]
   * @param {string} [options.key] the name of the position field
   * @param {number} [options.start] the number given to the first row
   * @param {jQuery} [options.spacing] a row used for gaps, this enables the spacing links. Gaps are sent with a null id
   */
  static init ({ table, url, key = "order", start = 1, spacing = null }) {
    const $table = $(table);
    const $rows = $table.find("tbody");
    const $editOrderLink = $(".edit-order-link");
    const $saveOrderLink = $(".save-order-link");
    const $addSpacingLink = $(".add-spacing-link");

    if (spacing) {
      $(".add-spacing-above-link").off("click.gayfurcity.spacing").on("click.gayfurcity.spacing", function (event) {
        event.preventDefault();
        SortableTable.addSpacing(spacing).insertBefore($(this).closest("tr"));
      });

      $(".add-spacing-below-link").off("click.gayfurcity.spacing").on("click.gayfurcity.spacing", function (event) {
        event.preventDefault();
        SortableTable.addSpacing(spacing).insertAfter($(this).closest("tr"));
      });

      $table.off("click.gayfurcity.spacing").on("click.gayfurcity.spacing", ".remove-spacing-link", function (event) {
        event.preventDefault();
        $(this).closest("tr").remove();
      });
    }

    const startEditing = function () {
      $saveOrderLink.show();
      $editOrderLink.hide();
      if (spacing) {
        $addSpacingLink.show();
        $table.find(".remove-spacing-link").show();
      }
      // calling sortable() again on an existing one doesn't re-enable it after saving
      if ($rows.sortable("instance")) {
        $rows.sortable("enable");
      } else {
        $rows.sortable();
      }
    };

    const stopEditing = function () {
      $saveOrderLink.hide();
      if (spacing) {
        $addSpacingLink.hide();
        $table.find(".remove-spacing-link").hide();
      }
      $rows.sortable("disable");
    };

    $editOrderLink.off("click.gayfurcity.sorting").on("click.gayfurcity.sorting", function (event) {
      event.preventDefault();
      startEditing();
      Utility.notice("Drag and drop to reorder.");
    });

    $saveOrderLink.off("click.gayfurcity.sorting").on("click.gayfurcity.sorting", function (event) {
      event.preventDefault();
      stopEditing();
      const data = SortableTable.reorderData($table, key, start);
      $.ajax({
        url,
        type: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        data: JSON.stringify(data),
        success () {
          Utility.notice("Order updated.");
          $editOrderLink.show();
        },
        error (xhr) {
          const message = xhr.responseJSON?.message;
          Utility.error(`Failed to update order${message ? `: ${message}` : "."}`);
          startEditing();
        },
      });
    });
  }

  // a copy, so more than one gap can be added
  static addSpacing (spacing) {
    const $row = spacing.clone();
    $row.find(".remove-spacing-link").show();
    return $row;
  }

  static reorderData ($table, key, start) {
    return Array.from($table.find("tbody tr")).map((element, index) => ({
      id: element.dataset.id ? Number(element.dataset.id) : null,
      [key]: index + start,
    }));
  }
}

export default SortableTable;
