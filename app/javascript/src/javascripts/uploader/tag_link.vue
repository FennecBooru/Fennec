<template>
  <a :class="'tag-type-' + tagType" :href="href" target="_blank">
    {{ name }}
  </a>
</template>

<script>
  import Uploader from "../uploader";

  export default {
    props: ["tagType", "name"],
    computed: {
      href: function () {
        if (Uploader.settings?.wiki_enabled === false) return "/posts?tags=" + encodeURIComponent(this.name);
        return "/wiki/show_or_new?title=" + encodeURIComponent(this.name);
      },
    },
  }
</script>
