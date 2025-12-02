import { type DirectiveBinding } from 'vue';

const overlay = document.createElement('div');
overlay.className = 'brackets-overlay';
overlay.innerHTML = `<div class="bracket-helper"></div>`;
overlay.style.position = 'absolute';
overlay.style.pointerEvents = 'none';
overlay.style.display = 'none';

document.addEventListener('DOMContentLoaded', () => {
  let root = document.getElementById('brackets-root');

  if (root === null) {
    root = document.createElement('div');

    root.id = 'brackets-root';

    document.body.appendChild(root);
  }

  root.appendChild(overlay);
});

// Track active element
let activeEl: HTMLElement | null = null;
let resizeObs: ResizeObserver | null = null;
let intersectObs: IntersectionObserver | null = null;

// Store event listener references per element
const listenerMap = new WeakMap<
  HTMLElement,
  {
    onMouseEnter: () => void;
    onMouseLeave: () => void;
    onFocus: () => void;
    onBlur: () => void;
  }
>();

function positionOverlay(el: HTMLElement): void {
  const rect = el.getBoundingClientRect();
  overlay.style.top = `${rect.top + window.scrollY}px`;
  overlay.style.left = `${rect.left + window.scrollX}px`;
  overlay.style.width = `${rect.width}px`;
  overlay.style.height = `${rect.height}px`;
}

function showOverlay(el: HTMLElement, state: 'hovering' | 'focused' | 'selected'): void {
  activeEl = el;
  overlay.style.display = 'block';
  overlay.classList.remove('hovering', 'focused', 'selected');
  overlay.classList.add(state);
  positionOverlay(el);

  if (resizeObs !== null) {
    resizeObs.disconnect();
  }
  resizeObs = new ResizeObserver(() => {
    if (activeEl !== null) {
      positionOverlay(activeEl);
    }
  });
  resizeObs.observe(el);

  if (intersectObs !== null) {
    intersectObs.disconnect();
  }
  intersectObs = new IntersectionObserver((entries) => {
    if (entries.length > 0 && entries[0]?.isIntersecting && activeEl !== null) {
      positionOverlay(activeEl);
    }
  });
  intersectObs.observe(el);
}

function hideOverlay(state?: 'hovering' | 'focused'): void {
  if (state !== undefined) {
    overlay.classList.remove(state);
  }
  if (!overlay.classList.contains('selected')) {
    overlay.style.display = 'none';
    activeEl = null;
    if (resizeObs !== null) {
      resizeObs.disconnect();
      resizeObs = null;
    }
    if (intersectObs !== null) {
      intersectObs.disconnect();
      intersectObs = null;
    }
  }
}

export default {
  mounted(el: HTMLElement, binding: DirectiveBinding) {
    const { size = '0.5rem', selected = false, disabled = false } = binding.value || {};
    overlay.style.setProperty('--bracket-size', size);
    overlay.classList.toggle('item-disabled', disabled);

    const onMouseEnter = (): void => {
      showOverlay(el, 'hovering');
    };
    const onMouseLeave = (): void => {
      hideOverlay('hovering');
    };
    const onFocus = (): void => {
      showOverlay(el, 'focused');
    };
    const onBlur = (): void => {
      hideOverlay('focused');
    };

    el.addEventListener('mouseenter', onMouseEnter);
    el.addEventListener('mouseleave', onMouseLeave);
    el.addEventListener('focus', onFocus);
    el.addEventListener('blur', onBlur);

    listenerMap.set(el, { onMouseEnter, onMouseLeave, onFocus, onBlur });

    if (selected) {
      showOverlay(el, 'selected');
    }
  },
  updated(el: HTMLElement, binding: DirectiveBinding) {
    const { size = '0.5rem', selected = false, disabled = false } = binding.value || {};
    overlay.style.setProperty('--bracket-size', size);
    overlay.classList.toggle('item-disabled', disabled);

    if (selected) {
      showOverlay(el, 'selected');
    } else {
      if (overlay.classList.contains('selected')) {
        overlay.classList.remove('selected');
        hideOverlay();
      }
    }
  },
  unmounted(el: HTMLElement) {
    const listeners = listenerMap.get(el);
    if (listeners !== undefined) {
      el.removeEventListener('mouseenter', listeners.onMouseEnter);
      el.removeEventListener('mouseleave', listeners.onMouseLeave);
      el.removeEventListener('focus', listeners.onFocus);
      el.removeEventListener('blur', listeners.onBlur);
      listenerMap.delete(el);
    }
    if (activeEl === el) {
      hideOverlay();
    }
  },
};
