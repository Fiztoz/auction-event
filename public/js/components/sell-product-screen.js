import { state } from "../store.js";
import {
  listProductForAuction, cancelSell, uploadProductImage, removeProductImage
} from "../actions.js";

const { ref, computed } = Vue;

const CATEGORIES = ["electronics", "collectibles", "fashion", "home", "toys", "other"];

export const SellProductScreen = {
  setup() {
    const step = ref(0);
    const next = () => { step.value = 1; };
    const back = () => { step.value = 0; };
    const editing = computed(() => !!state.editingProductId);
    const detailsReady = () =>
      state.form.product_title.trim() &&
      state.form.product_description.trim() &&
      state.form.product_category;
    const onPick = (e) => {
      const file = e.target.files[0];
      e.target.value = ""; // allow re-picking the same file after a remove
      uploadProductImage(file);
    };
    return {
      state, step, next, back, editing, detailsReady, onPick,
      listProductForAuction, cancelSell, removeProductImage, CATEGORIES
    };
  },
  template: `
    <div class="card">
      <h1>{{ editing ? 'Edit auction' : 'Sell at auction' }}</h1>
      <p class="subtitle">{{ step === 0 ? 'Step 1 of 2 — Product details' : 'Step 2 of 2 — Auction terms' }}</p>
      <div class="steps">
        <div class="dot active"></div>
        <div class="dot" :class="{ active: step === 1 }"></div>
      </div>

      <form v-if="step === 0" @submit.prevent="next">
        <label>Title</label>
        <input type="text" maxlength="120" v-model="state.form.product_title" required>
        <label>Description</label>
        <textarea rows="3" v-model="state.form.product_description" required></textarea>
        <label>Category</label>
        <select v-model="state.form.product_category" required>
          <option value="" disabled>Select category…</option>
          <option v-for="c in CATEGORIES" :key="c" :value="c">{{ c }}</option>
        </select>

        <label>Photos (optional, up to 3)</label>
        <div class="thumb-grid">
          <div class="thumb" v-for="(img, i) in state.form.product_images" :key="img">
            <img :src="img" alt="">
            <button type="button" class="thumb-remove" @click="removeProductImage(i)" aria-label="Remove">×</button>
          </div>
        </div>
        <input type="file" accept="image/*" @change="onPick"
               v-if="state.form.product_images.length < 3 && !state.imageUploading">
        <p class="subtitle" v-if="state.imageUploading">Uploading…</p>
        <div v-if="state.error" class="error">{{ state.error }}</div>

        <button :disabled="!detailsReady() || state.imageUploading">Next</button>
        <button type="button" class="link-button" @click="cancelSell">Cancel</button>
      </form>

      <form v-else @submit.prevent="listProductForAuction">
        <label>Starting price (USD)</label>
        <input type="number" min="0.01" step="0.01" v-model="state.form.product_starting_price" required>
        <label>Auction duration (days)</label>
        <input type="number" min="1" max="30" step="1" v-model="state.form.product_duration" required>
        <div v-if="state.error" class="error">{{ state.error }}</div>
        <button :disabled="state.submitting">
          {{ state.submitting ? 'Saving…' : (editing ? 'Save changes' : 'Save draft') }}
        </button>
        <button type="button" class="link-button" @click="back">Back</button>
      </form>
    </div>
  `
};
