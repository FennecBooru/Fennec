<template>
    <button class="toggle-button" :class="{active: value}" @click="value = !value">{{check.name}}</button>
</template>

<script>
  export default {
    props: ['check', 'checks'],
    computed: {
      value: {
        get() {
          return this.checks[this.check.tag] === true;
        },
        set(v) {
          this.$emit('set', this.check.tag, v);
        }
      }
    }
  }
</script>
