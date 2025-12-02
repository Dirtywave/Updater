/**
 * Brackets Directive — Technical Overview
 * ---------------------------------------
 *
 * This directive renders a non-interactive “bracket overlay” around an element
 * to visually indicate three different interaction states:
 *
 *   1. Hover (mouse-driven)
 *   2. Focus (keyboard-driven)
 *   3. Selected (persistent programmatic state)
 *
 * The overlay is an absolutely-positioned element appended inside the host
 * element. It never affects layout or hit-testing.
 *
 *
 * STATE MODEL
 * -----------
 *
 * Each bracketed element may be in zero or more of the following states:
 *
 *   - hovering
 *       Applied when the mouse pointer is inside the element AND the element
 *       is the deepest non-focusOnly bracket target under the pointer.
 *
 *   - focused
 *       Applied when the element receives DOM focus. For focusOnly elements,
 *       this is only applied if the focus originated from keyboard navigation.
 *
 *   - selected
 *       Applied when the user or application explicitly marks the element as
 *       selected. This state is independent of hover/focus and persists until
 *       cleared externally.
 *
 * The overlay is visible whenever ANY of these states are active.
 *
 *
 * FOCUS ORIGIN RULES
 * ------------------
 *
 * The directive distinguishes between keyboard focus and mouse focus:
 *
 *   - Keyboard focus (Tab, Arrow keys, etc.)
 *       → focusOnly elements show brackets
 *       → overlay receives `.focused` + `.focus-origin-keyboard`
 *
 *   - Mouse focus (click)
 *       → focusOnly elements DO NOT show brackets
 *       → overlay does NOT receive `.focused`
 *
 * This allows focusOnly elements to behave like true “keyboard focus rings.”
 *
 * Additionally, keyboard-origin focus is cleared automatically when the user
 * moves the mouse again. This mirrors native browser focus-ring behavior.
 *
 *
 * HOVER BEHAVIOR & NESTED ELEMENTS
 * --------------------------------
 *
 * The directive supports arbitrarily nested bracketed elements. On pointer
 * movement, the directive:
 *
 *   1. Collects all bracketed elements under the pointer.
 *   2. Sorts them by DOM depth.
 *   3. Selects the deepest element that is NOT focusOnly.
 *   4. Applies `.hovering` to that element only.
 *
 * This ensures:
 *
 *   - Descendants take precedence over ancestors.
 *   - focusOnly elements never swallow hover.
 *   - Hover transitions between nested elements are smooth and predictable.
 *
 *
 * OVERLAY POSITIONING
 * -------------------
 *
 * The overlay is sized to match the host element’s bounding box. It updates on:
 *
 *   - ResizeObserver events
 *   - IntersectionObserver visibility changes
 *   - Any time a state change makes the overlay visible
 *
 * This guarantees correct sizing even in dynamic layouts.
 *
 *
 * SUMMARY OF INTENDED UX
 * ----------------------
 *
 *   - Hovering an element → brackets appear (mouse affordance)
 *   - Tabbing to an element → brackets appear (keyboard focus ring)
 *   - Clicking a focusOnly element → NO brackets (mouse focus suppressed)
 *   - Moving the mouse after keyboard focus → keyboard focus brackets clear
 *   - Selecting an element → brackets appear persistently
 *   - Nested elements → deepest actionable element wins
 *
 * This directive provides a unified, consistent “activation affordance” that
 * adapts to both mouse and keyboard input while avoiding visual conflicts.
 */

import type { Directive } from 'vue';

export type BracketsDirectiveProps = {
  disabled?: boolean;
  focusOnly?: boolean;
  offset?: number;
  onFocusChange?: (focused: boolean) => void;
  onHoverChange?: (hovering: boolean) => void;
  render?: boolean;
  selected?: boolean;
  size?: string;
  target?: string;
};

export type BracketsDirective = Directive<HTMLElement, BracketsDirectiveProps>;

type BracketState = {
  el: HTMLElement;
  overlay: HTMLElement;
  props: BracketsDirectiveProps;
  hovering: boolean;
  focused: boolean;
  focusOriginKeyboard: boolean;
  disabled: boolean;
  cleanup: (() => void)[];
  resizeObs?: ResizeObserver;
  intersectObs?: IntersectionObserver;
};

const hoverStack: BracketState[] = [];

let lastFocusWasKeyboard = false;

// Global focus-origin tracking
window.addEventListener('keydown', () => {
  lastFocusWasKeyboard = true;
});

window.addEventListener('mousedown', () => {
  lastFocusWasKeyboard = false;

  // Clear keyboard-origin focus styling when mouse is used again
  hoverStack.forEach((state) => {
    if (state.focusOriginKeyboard) {
      state.focusOriginKeyboard = false;

      updateClasses(state);
    }
  });
});

function createOverlay(): HTMLElement {
  const overlay = document.createElement('div');
  overlay.className = 'brackets-overlay';

  const helper = document.createElement('div');
  helper.className = 'bracket-helper';

  overlay.appendChild(helper);

  return overlay;
}

function updateOverlayPosition(state: BracketState) {
  const rect = state.el.getBoundingClientRect();
  const style = state.overlay.style;

  // We keep overlay positioned relative to the host
  style.top = '0';
  style.left = '0';
  style.width = rect.width + 'px';
  style.height = rect.height + 'px';
}

function updateClasses(state: BracketState) {
  const { overlay, hovering, focused, focusOriginKeyboard, props } = state;

  overlay.classList.toggle('hovering', hovering);
  overlay.classList.toggle('focused', focused);
  overlay.classList.toggle('focus-origin-keyboard', focusOriginKeyboard);
  overlay.classList.toggle('focus-only', Boolean(props.focusOnly));
  overlay.classList.toggle('item-disabled', Boolean(props.disabled));

  if (props.offset != null) {
    overlay.style.setProperty('--bracket-offset', `${props.offset}px`);
  }

  if (props.size) {
    overlay.style.setProperty('--bracket-size', props.size);
  }

  // Optional external render control (e.g., force hide)
  if (props.render === false) {
    overlay.style.display = 'none';
  } else {
    // Let CSS decide visibility based on classes
    overlay.style.removeProperty('display');
  }
}

function pushHover(state: BracketState) {
  if (!hoverStack.includes(state)) {
    hoverStack.push(state);
  }

  resolveHoverStates();
}

function popHover(state: BracketState) {
  const idx = hoverStack.indexOf(state);

  if (idx !== -1) {
    hoverStack.splice(idx, 1);
  }

  // Explicitly clear hover state on this element
  if (state.hovering) {
    state.hovering = false;

    state.props.onHoverChange?.(false);

    updateClasses(state);
  }

  resolveHoverStates();
}

// Determines if a given state is currently "rendering brackets"
function isRenderingBrackets(state: BracketState): boolean {
  if (state.hovering && !state.props.focusOnly) {
    return true;
  }

  if (state.focused && state.focusOriginKeyboard) {
    return true;
  }

  return false;
}

function resolveHoverStates() {
  if (hoverStack.length === 0) {
    // Clear hover on all known states in stack
    hoverStack.forEach((s) => {
      if (s.hovering) {
        s.hovering = false;

        s.props.onHoverChange?.(false);

        updateClasses(s);
      }
    });

    return;
  }

  const top = hoverStack[hoverStack.length - 1];

  if (top) {
    hoverStack.forEach((state) => {
      // Ancestors should lose hover only if a descendant is actually rendering brackets
      const descendantVisible = top !== state && isRenderingBrackets(top);

      const shouldHover = state === top && !descendantVisible;

      if (state.hovering !== shouldHover) {
        state.hovering = shouldHover;

        state.props.onHoverChange?.(shouldHover);

        updateClasses(state);
      }
    });
  }
}

export const bracketsDirective = {
  mounted(el, binding) {
    const props: BracketsDirectiveProps = binding.value || {};

    const overlay = createOverlay();

    // Allow custom target inside the host (e.g., a specific child)
    const target =
      props.target && el.querySelector<HTMLElement>(props.target)
        ? el.querySelector<HTMLElement>(props.target)!
        : el;

    // Ensure host (or target) can position the overlay
    if (getComputedStyle(target).position === 'static') {
      target.style.position = 'relative';
    }

    target.appendChild(overlay);

    const state: BracketState = {
      el: target,
      overlay,
      props,
      hovering: false,
      focused: false,
      focusOriginKeyboard: false,
      disabled: !!props.disabled,
      cleanup: [],
    };

    // Hover handling
    // const onEnter = () => {
    //   if (state.disabled) return;
    //   pushHover(state);
    // };
    const onEnter = () => {
      if (state.disabled) {
        return;
      }

      // focusOnly elements should not participate in hover arbitration
      if (state.props.focusOnly) {
        return;
      }

      pushHover(state);
    };

    const onLeave = () => {
      if (state.props.focusOnly) {
        return;
      }

      popHover(state);
    };

    el.addEventListener('mouseenter', onEnter);
    el.addEventListener('mouseleave', onLeave);

    state.cleanup.push(() => {
      el.removeEventListener('mouseenter', onEnter);
      el.removeEventListener('mouseleave', onLeave);
    });

    // Focus handling (use capture to catch focus on descendants)
    const onFocus = (_event: FocusEvent) => {
      if (state.disabled) {
        return;
      }

      // Only treat THIS element as focused if it is the actual focused element
      if (document.activeElement !== state.el) {
        return;
      }

      const isKeyboard = lastFocusWasKeyboard;

      const shouldShowFocus = !state.props.focusOnly || isKeyboard;

      state.focused = shouldShowFocus;

      state.focusOriginKeyboard = isKeyboard && shouldShowFocus;

      state.props.onFocusChange?.(state.focused);

      updateClasses(state);

      updateOverlayPosition(state);
    };
    const onBlur = (_event: FocusEvent) => {
      if (document.activeElement === state.el) {
        // Still focused, ignore blur
        return;
      }

      state.focused = false;

      state.focusOriginKeyboard = false;

      state.props.onFocusChange?.(false);

      updateClasses(state);
    };

    el.addEventListener('focus', onFocus, true);
    el.addEventListener('blur', onBlur, true);

    state.cleanup.push(() => {
      el.removeEventListener('focus', onFocus, true);
      el.removeEventListener('blur', onBlur, true);
    });

    // ResizeObserver
    if (typeof ResizeObserver !== 'undefined') {
      state.resizeObs = new ResizeObserver(() => {
        updateOverlayPosition(state);
      });

      state.resizeObs.observe(target);
    }

    // IntersectionObserver
    if (typeof IntersectionObserver !== 'undefined') {
      state.intersectObs = new IntersectionObserver((entries) => {
        const entry = entries[0];

        if (entry && entry.isIntersecting) {
          updateOverlayPosition(state);
        }
      });

      state.intersectObs.observe(target);
    }

    state.cleanup.push(() => {
      state.resizeObs?.disconnect();

      state.intersectObs?.disconnect();
    });

    // Initial render
    updateClasses(state);

    updateOverlayPosition(state);

    (el as any).__brackets_state = state;
  },

  updated(el, binding) {
    const state = (el as any).__brackets_state as BracketState | undefined;

    if (!state) {
      return;
    }

    state.props = binding.value || {};

    state.disabled = !!state.props.disabled;

    // If disabled while hovering/focused, clear states
    if (state.disabled) {
      if (state.hovering) {
        state.hovering = false;

        state.props.onHoverChange?.(false);
      }

      if (state.focused) {
        state.focused = false;

        state.focusOriginKeyboard = false;

        state.props.onFocusChange?.(false);
      }
    }

    updateClasses(state);

    updateOverlayPosition(state);
  },

  unmounted(el) {
    const state = (el as any).__brackets_state as BracketState | undefined;

    if (!state) {
      return;
    }

    // Remove from hover stack if present
    popHover(state);

    state.cleanup.forEach((fn) => fn());

    state.overlay.remove();

    delete (el as any).__brackets_state;
  },
} satisfies BracketsDirective;
