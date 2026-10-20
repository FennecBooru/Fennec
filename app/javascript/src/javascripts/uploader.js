import VueUploader from "./uploader/uploader.vue.erb";
import { createApp } from "vue";
import {SendQueue} from "./send_queue";
import Page from "./utility/page";

/**
 * @typedef UploadSettings
 * @prop {number} user_id
 * @prop {boolean} compact_mode
 * @prop {boolean} safe_site
 * @prop {?string} post_tags
 * @prop {string[]} upload_tags
 * @prop {string[]} recent_tags
 * @prop {boolean} allow_locked_tags
 * @prop {boolean} allow_rating_lock
 * @prop {boolean} allow_upload_as_pending
 * @prop {boolean} allow_upload_as_in_progress
 * @prop {number} max_file_size
 * @prop {Record<string, number>} max_file_size_map
 * @prop {number} max_file_size_per_request
 * @prop {boolean} wiki_enabled
 * @prop {UploaderSection[]} layout
 * @prop {number} minimum_tags
 */

/**
 * @typedef UploaderSection
 * @prop {string} kind tags, or the built in section's name
 * @prop {string} key
 * @prop {string} label
 * @prop {string} hint rendered html
 * @prop {string} placeholder
 * @prop {"none"|"always"|"in_progress"} requirement
 * @prop {boolean} show_in_compact_mode
 * @prop {UploaderButton[][]} rows
 */

/**
 * @typedef UploaderButton
 * @prop {string} name
 * @prop {string} tag
 * @prop {string[]} shown_when
 * @prop {"any"|"all"} shown_when_mode
 */

/**
 * @prop {UploadSettings?} settings
 * @prop {number?} settingsPostID
 */
class Uploader {
  static settings = null;

  static settingsPostID = null;

  static init () {
    const app = createApp(VueUploader);
    app.mount("#uploader");
  }

  /** @return UploadSettings */
  static async getSettings (postID = null) {
    if (this.settings && this.settingsPostID === postID) return this.settings;
    return new Promise(resolve => {
      SendQueue.add(() => {
        $.ajax({
          type: "get",
          url: `/uploads/settings.json${postID ? `?post_id=${postID}` : ""}`,
          success: (response) => {
            resolve(response);
          },
        });
      });
    });
  }

  static async loadSettings (postID = null) {
    if (this.settings && this.settingsPostID === postID) return;
    this.settings = await this.getSettings(postID);
    this.settingsPostID = postID;
  }
}

export default Uploader;

$(async function () {
  if (Page.matches("uploads", "new")) {
    await Uploader.loadSettings();
    Uploader.init();
  }
});
