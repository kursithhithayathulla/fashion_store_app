# High-End Fashion Design System Document

## 1. Overview & Creative North Star
**Creative North Star: "The Digital Atelier"**

This design system is engineered to elevate the digital presence of a luxury fashion house. Unlike standard e-commerce templates that rely on rigid grids and heavy borders, "The Digital Atelier" treats the screen as a high-end editorial spread. We prioritize breathability, tonal depth, and intentional asymmetry to evoke the feeling of a bespoke physical boutique. 

The system moves away from "flat" design by utilizing a layering principle that mimics fine paper and frosted glass. By breaking the grid with overlapping typography and floating product modules, we create a signature visual rhythm that feels curated, not processed.

---

## 2. Colors
Our palette balances the warmth of artisanal gold with the grounded authority of charcoal and deep umber.

*   **Primary Hierarchy:** Use `primary` (#735C00) for text-based CTAs and `primary_container` (#D4AF37) for high-impact surfaces.
*   **The Charcoal Anchor:** `secondary` (#685B5B) and its container variants provide a sophisticated alternative to pure black, offering a "coffee and smoke" tonal quality.
*   **The "No-Line" Rule:** **Prohibit the use of 1px solid borders for sectioning.** Boundaries must be defined solely through background color shifts. For example, a `surface_container_low` section should sit directly against a `surface` background to create a seamless, sophisticated transition.
*   **The "Glass & Gradient" Rule:** To achieve professional polish, main CTAs should utilize a subtle linear gradient from `primary` to `primary_container`. For floating navigation or over-image overlays, use Glassmorphism: apply a `surface` color at 70% opacity with a 20px backdrop-blur.

---

## 3. Typography
Luxury is expressed through the tension between an authoritative serif and a functional, modern sans-serif.

*   **Display & Headlines (Noto Serif):** These are our "editorial" voices. Use `display-lg` and `headline-lg` with generous tracking (-2%) to create a high-fashion, masthead feel. Use these for collection titles and hero statements.
*   **Body & Titles (Manrope):** Our "functional" voice. Manrope provides a clean, geometric contrast to the serif. `body-lg` (1rem) is our standard for product descriptions, ensuring maximum readability without sacrificing style.
*   **Labels & Metadata:** Use `label-md` in all-caps with +10% letter spacing for categories (e.g., "NEW ARRIVALS") to mimic luxury garment tags.

---

## 4. Elevation & Depth
We define hierarchy through **Tonal Layering** rather than structural lines or heavy drop shadows.

*   **The Layering Principle:** Depth is achieved by "stacking" surface tiers.
    *   *Base:* `surface` (#F9F9F9)
    *   *Mid-ground:* `surface_container_low` (#F3F3F3)
    *   *Foreground/Cards:* `surface_container_lowest` (#FFFFFF)
*   **Ambient Shadows:** When an element must float (like a "Quick Buy" button), use an extra-diffused shadow.
    *   *Value:* `0px 12px 32px`
    *   *Color:* `on_surface` at 4% opacity. This mimics natural light rather than a digital effect.
*   **The "Ghost Border" Fallback:** If a container requires a border for accessibility, use `outline_variant` at 15% opacity. Never use 100% opaque borders.

---

## 5. Components

### Buttons
*   **Primary:** Solid `secondary` (#685B5B) with `on_secondary` (#FFFFFF) text. Rounded corners at `xl` (0.75rem / 12px).
*   **Interactive Accents:** Use `tertiary` (#005BC0) or vibrant orange accents sparingly for interactive states (hover/focus) to guide the eye without breaking the luxury aesthetic.
*   **Shape:** Follow the `xl` (12px) scale for a modern, approachable feel that aligns with the brand's rounded visual identity.

### Input Fields
*   **Styling:** Forgo the traditional box. Use a `surface_container` background with a `ghost border` at the bottom only, or a fully rounded container with `surface_container_highest` for a "pill" look that matches the logo's fluidity.
*   **Icons:** Use thin-stroke icons (1.5px weight) to maintain an elegant, airy feel.

### Cards & Lists
*   **Layout:** **Forbid the use of divider lines.** Separate products using the Spacing Scale (minimum 32px vertical margin).
*   **Nesting:** Product images should sit in a `surface_container_low` wrapper to provide a soft frame that doesn't feel "boxed in."

### Selection Chips
*   **State:** Selected states should use `primary_fixed` (#FFE088) with a soft `surface_tint` to indicate active choices in size or color selection.

---

## 6. Do's and Don'ts

### Do
*   **Do** use intentional white space. If you think there is enough room, add 16px more.
*   **Do** overlap elements. Allow a serif headline to slightly overlap a product image to create an editorial, layered look.
*   **Do** use "surface-on-surface" for hierarchy. Place a white card on a light gray background for a soft, premium lift.

### Don't
*   **Don't** use pure black (#000000). Always use the `secondary` or `on_surface` tokens to maintain tonal warmth.
*   **Don't** use high-contrast borders. They "trap" the design and make it feel like a generic template.
*   **Don't** use standard "Material Design" blue for links. Use the `primary` gold or `tertiary` blue defined in the palette to stay within the brand's signature ecosystem.