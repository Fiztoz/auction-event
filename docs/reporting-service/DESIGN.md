# PEA Design System — Implementation Specification

> **Purpose of this document.** This is a complete, self-contained build specification for the **PEA Design System** (`@pea-ds/*`). An engineer or agent should be able to recreate the entire system — token pipeline, theming, and every component — from this file alone, without seeing the original source. Where exact values matter (sizes, token names, colors, behavior), they are given explicitly.

---

## 1. Overview & Principles

The PEA Design System is a **multi-brand, multi-theme React component library**, distributed as a set of independently-versioned npm packages under the `@pea-ds/*` scope.

**Non-negotiable design principles:**

1. **Zero runtime UI dependencies.** No Radix, no Tailwind runtime, no CSS-in-JS library. Components are plain React function components using inline `style` objects + a handful of generated utility classes.
2. **Everything is a token.** Components never hardcode colors, spacing, radii, or typography. They read **CSS custom properties** (`--pea-*`). This is what makes theming and rebranding work without touching component code.
3. **Three-layer token architecture.** Primitive → Semantic (per theme) → Component. Compiled to CSS via Style Dictionary.
4. **Controlled & uncontrolled.** Every stateful component supports both a controlled prop (`isChecked`, `value`, …) and an uncontrolled default (`defaultChecked`, `defaultValue`, …), following the standard React pattern.
5. **Accessible by default.** Proper ARIA roles/attributes, visible focus rings (2px offset + colored ring), keyboard support, `aria-disabled`/`aria-busy` where relevant.
6. **React ≥ 19** is a hard peer dependency for all packages.
7. **`"use client"`** directive at the top of every component file (Next.js App Router / RSC compatibility).

**Target tech stack:** React 19, TypeScript 5.9, Style Dictionary 5, Storybook 10, Vitest 4 + Playwright, Next.js 16 (playground only).

---

## 2. Repository Structure

Monorepo using **npm workspaces**. Workspace glob: `projects/*`.

```
design-system/
├── package.json                # root: workspaces, scripts, shared devDeps
├── tsconfig.base.json          # shared TS compiler options
├── tsconfig.json               # path aliases for local dev
├── vitest.config.js            # root test config (Storybook + Playwright)
├── .storybook/                 # Storybook 10 config
├── manifest/                   # Helm/CI deploy values (test/value/valueProd .yml)
├── Dockerfile / docker-compose.yml
├── .gitlab-ci.yml              # CI pipeline
└── projects/
    ├── base/                   # @pea-ds/base — tokens + ThemeProvider + enums
    ├── button/                 # @pea-ds/button
    ├── checkbox/               # @pea-ds/checkbox
    ├── input/                  # @pea-ds/input
    ├── radio/                  # @pea-ds/radio
    ├── toggle/                 # @pea-ds/toggle
    ├── tooltip/                # @pea-ds/tooltip
    ├── avatar/                 # @pea-ds/avatar
    ├── navigation/             # @pea-ds/navigation (preview / WIP)
    └── playground/             # Next.js dev + demo app (private, not published)
```

### Package registry

| Package | Version | Exports |
|---|---|---|
| `@pea-ds/base` | 0.1.4 | `ThemeProvider`, `useTheme`, `ThemeEnum`, `Brand`, `BRAND`, `DEFAULT_THEME` + CSS token/typography files |
| `@pea-ds/button` | 0.1.5 | `Button` (+ `ButtonSplit`, internal/demo) |
| `@pea-ds/checkbox` | 0.1.3 | `Checkbox` |
| `@pea-ds/input` | 0.1.2 | `Input` |
| `@pea-ds/radio` | 0.1.1 | `Radio`, `RadioGroup` |
| `@pea-ds/toggle` | 0.1.2 | `Toggle` |
| `@pea-ds/tooltip` | 0.1.3 | `Tooltip` |
| `@pea-ds/avatar` | 0.1.0 | `Avatar`, `AvatarLabelGroup` |
| `@pea-ds/navigation` | 0.1.2-preview | (preview) |

---

## 3. Package Conventions

Every published component package follows the **same skeleton**:

**`package.json`** (component packages — note `@pea-ds/base` is special, see §5):
```jsonc
{
  "name": "@pea-ds/<component>",
  "version": "0.1.x",
  "main": "./dist/index.js",
  "types": "./dist/types/index.d.ts",
  "exports": {
    ".": {
      "types": "./dist/types/index.d.ts",
      "import": "./dist/index.js",
      "default": "./dist/index.js"
    }
  },
  "files": ["dist"],
  "peerDependencies": { "react": ">=19", "react-dom": ">=19" },
  "scripts": { "build": "tsc -p tsconfig.build.json" }
}
```

**`tsconfig.build.json`** (identical for every component package):
```jsonc
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "module": "ESNext",
    "moduleResolution": "bundler",
    "outDir": "dist",
    "declaration": true,
    "declarationDir": "dist/types",
    "emitDeclarationOnly": false
  },
  "include": ["src"]
}
```

**`src/` layout:**
```
src/
├── <Component>.tsx          # the component (named export)
├── <Component>.stories.tsx  # Storybook story = also the test target
├── <Component>.demo.tsx     # (optional) demo composition
└── index.ts                 # re-export component + its types
```

**Root `tsconfig.base.json`** (shared):
```jsonc
{
  "compilerOptions": {
    "target": "ES2020",
    "strict": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "jsx": "react-jsx"
  },
  "exclude": ["**/*.stories.ts", "**/*.stories.tsx", "**/*.test.ts", "**/*.spec.ts", "**/__tests__/**"]
}
```

Component packages do **not** depend on `@pea-ds/base` at the JS level — they only consume its CSS variables at runtime. The consuming app is responsible for importing the base CSS and wrapping in `ThemeProvider`.

---

## 4. Token Architecture (the core of the system)

Tokens live in `@pea-ds/base` and compile to CSS custom properties via **Style Dictionary 5**. There are **three layers**:

```
Layer 1  PRIMITIVE  — raw, brand-agnostic values (never change)
Layer 2  SEMANTIC   — contextual aliases, swap per theme (light/dark/high-contrast)
Layer 3  COMPONENT  — component-specific tokens (e.g. button bg), per theme
```

All CSS variables are prefixed `--pea-`. Token source files are W3C-style JSON (`{ "value": ..., "type": ... }`) and use `{group.key}` reference syntax.

### 4.1 Directory layout

```
projects/base/tokens/
├── primitive/
│   ├── size.json           # the unitless number scale everything references
│   ├── spacing.json        # space-* → references size.*
│   ├── radius.json         # rounded-* → references size.*
│   ├── width.json          # w-*, max-w-* → references size.*
│   ├── container.json      # padding/max-width → references size.*
│   ├── typography.json     # font-family/weight/size/line-height/letter-spacing
│   └── colors.json         # full color palette (brand-agnostic ramps)
├── semantic/
│   ├── light.json          # Layer 2 for light theme
│   ├── dark.json           # Layer 2 for dark theme
│   └── high-contrast.json  # Layer 2 for high-contrast theme
└── brand/
    ├── pea/{primitive.json, refs.json}      # brand primary ramp + brand refs
    └── brand-x/{primitive.json, refs.json}
```

### 4.2 Layer 1 — Primitive

**`size.json`** — the single source of numeric truth. Unitless floats. Keys are the literal numbers; negatives use `neg`-prefix encoding in CSS (`-1_6` → `--pea-size-neg1_6`). Defined values:

```
0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 28, 30, 32, 36, 38, 40, 44, 48,
60, 64, 72, 80, 90, 96, 128, 160, 192, 224, 256, 320, 384, 400, 480, 500,
560, 600, 640, 700, 720, 768, 1024, 1280, 1440, 1600, 1920, 9999,
-1_6, -0_8, -0_4, 0_4, 0_8, 1_6   (the *_* keys are decimals: 1_6 = 1.6)
```
Primitive `size` tokens are emitted **unitless** (e.g. `--pea-size-400: 400`).

**`spacing.json`** → `--pea-space-*` (emitted in **px**):
| Token | size ref | px |
|---|---|---|
| `space-0` | size.0 | 0 |
| `space-0_5` | size.2 | 2 |
| `space-1` | size.4 | 4 |
| `space-1_5` | size.6 | 6 |
| `space-2` | size.8 | 8 |
| `space-2_5` | size.10 | 10 |
| `space-3` | size.12 | 12 |
| `space-3_5` | size.14 | 14 |
| `space-4` | size.16 | 16 |
| `space-4_5` | size.18 | 18 |
| `space-5` | size.20 | 20 |
| `space-6` | size.24 | 24 |
| `space-8` | size.32 | 32 |
| `space-10` | size.40 | 40 |
| `space-12` | size.48 | 48 |
| `space-16` | size.64 | 64 |
| `space-20` | size.80 | 80 |
| `space-24` | size.96 | 96 |
| `space-32` | size.128 | 128 |
| `space-40` | size.160 | 160 |

**`radius.json`** → `--pea-rounded-*` (px):
`rounded-none`=0, `rounded-xxs`=2, `rounded-xs`=4, `rounded-sm`=6, `rounded-md`=8, `rounded-lg`=10, `rounded-xl`=12, `rounded-2xl`=16, `rounded-3xl`=20, `rounded-4xl`=24, `rounded-full`=9999.

**`width.json`** → `--pea-w-*` / `--pea-max-w-*` (px):
`w-xxs`=320, `w-xs`=384, `w-sm`=480, `w-md`=560, `w-lg`=640, `w-xl`=768, `w-2xl`=1024, `w-3xl`=1280, `w-4xl`=1440, `w-5xl`=1600, `w-6xl`=1920, `max-w-paragraph`=720.

**`container.json`** → `--pea-container-*` (px): `padding-mobile`=16, `padding-desktop`=32, `max-width-desktop`=1280.

**`typography.json`** → `--pea-font-*`, `--pea-line-height-*`, `--pea-letter-spacing-*`:

- **font-family** (unitless string):
  - `display` = `IBM Plex Sans Thai, sans-serif`
  - `body` = `Google Sans, sans-serif`
- **font-weight** (unitless; references `size.*`): `normal`=400, `medium`=500, `semibold`=600, `bold`=700.
- **font-size** (px): `text-xs`=12, `text-sm`=14, `text-md`=16, `text-lg`=18, `text-xl`=20, `display-xs`=24, `display-sm`=30, `display-md`=36, `display-lg`=48, `display-xl`=60, `display-2xl`=72.
- **line-height** (px): `text-xs`=18, `text-sm`=20, `text-md`=24, `text-lg`=28, `text-xl`=30, `display-xs`=32, `display-sm`=38, `display-md`=44, `display-lg`=60, `display-xl`=72, `display-2xl`=90.
- **letter-spacing** (px): `tightest`=-1.6, `tighter`=-0.8, `tight`=-0.4, `normal`=0, `wide`=0.4, `wider`=0.8, `widest`=1.6.

**`colors.json`** — brand-agnostic palette. Every ramp has steps `25,50,100,200,300,400,500,600,700,800,900,950` unless noted. Groups:
`base` (`white`=#ffffff, `black`=#000000, `transparent`=rgba(255,255,255,0)), `gray`, `gray-dark-mode`, `gray-dark-mode-alpha`, `error`, `warning`, `success`, `contrast` (HC-specific: `yellow-hc`, `yellow-hc-dark`, `pink-hc`, `error-hc`, `error-hc-dark`, `warning-hc`, `success-hc`), plus the extended palette: `gray-blue`, `gray-cool`, `gray-modern`, `gray-neutral`, `gray-iron`, `gray-true`, `gray-warm`, `moss`, `green-light`, `green`, `teal`, `cyan`, `blue-light`, `blue`, `blue-dark`, `indigo`, `violet`, `purple`, `fuchsia`, `pink`, `rose`, `orange-dark`, `orange`, `yellow`.

Reference `gray` ramp (the neutral spine):
```
25=#fdfdfd  50=#fafafa  100=#f5f5f5  200=#e9eaeb  300=#d5d7da  400=#a4a7ae
500=#717680 600=#535862  700=#414651  800=#252b37  900=#181d27  950=#0a0d12
```

### 4.3 Brand layer

Each brand supplies its **own primary color ramp** + reference overrides. The brand ramp is referenced by semantic tokens via `{brand.primary.*}`.

**`brand/pea/primitive.json`** — PEA magenta/fuchsia primary:
```
25=#fff7ff  50=#fdeefc  100=#fbd9f9  200=#f8bff4  300=#f4a1ec  400=#ef82e1
500=#e95ed2 600=#e134c1  700=#cf07aa  800=#a80689  900=#74045f  950=#450239
```
**`brand/brand-x/primitive.json`** — violet primary:
```
25=#fcfaff  50=#f9f5ff  100=#f4ebff  200=#e9d7fe  300=#d6bbfb  400=#b692f6
500=#9e77ed 600=#7f56d9  700=#6941c6  800=#53389e  900=#42307d  950=#2c1c5f
```
**`brand/<brand>/refs.json`** — maps semantic-ish `ref.*` aliases onto the brand ramp, e.g. (`pea`):
```
ref.text.brand-primary      = {brand.primary.900}
ref.text.brand-secondary    = {brand.primary.800}
ref.border.brand            = {brand.primary.700}
ref.fg.brand-primary        = {brand.primary.800}
ref.text.secondary-on-brand = {brand.primary.200}
...
```

### 4.4 Layer 2 — Semantic (per theme)

`semantic/{light,dark,high-contrast}.json` define the **same set of token paths**, pointing at different primitives per theme. This is the layer components actually read. Path families (full list):

- **`color.text.*`**: `primary`, `primary-on-brand`, `secondary`, `secondary-hover`, `secondary-on-brand`, `tertiary`, `tertiary-hover`, `tertiary-on-brand`, `quaternary`, `quaternary-on-brand`, `white`, `disabled`, `placeholder`, `placeholder-subtle`, `brand-primary`, `brand-secondary`, `brand-secondary-hover`, `brand-tertiary`, `brand-tertiary-alt`, `error-primary`, `error-primary-hover`, `warning-primary`, `success-primary`.
- **`color.border.*`**: `primary`, `secondary`, `secondary-alt`, `tertiary`, `disabled`, `disabled-subtle`, `brand`, `brand-alt`, `error`, `error-subtle`.
- **`color.fg.*`** (foreground / icon): `primary`, `secondary`, `secondary-hover`, `tertiary`, `tertiary-hover`, `quaternary`, `quaternary-hover`, `white`, `disabled`, `disabled-subtle`, `brand-primary`, `brand-primary-alt`, `brand-primary-on-brand`, `brand-secondary`, `brand-secondary-alt`, `brand-secondary-hover`, `error-primary`, `error-secondary`, `warning-primary`, `warning-secondary`, `success-primary`, `success-secondary`.
- **`color.bg.*`**: `primary`, `primary-alt`, `primary-hover`, `primary-solid`, `secondary`, `secondary-alt`, `secondary-hover`, `secondary-subtle`, `secondary-solid`, `tertiary`, `quaternary`, `active`, `disabled`, `disabled-subtle`, `overlay`, `brand-primary`, `brand-primary-alt`, `brand-secondary`, `brand-solid`, `brand-solid-hover`, `brand-section`, `brand-section-subtle`, `error-primary`, `error-secondary`, `error-solid`, `error-solid-hover`, `warning-primary/secondary/solid`, `success-primary/secondary/solid`.
- **`color.effect.focus-ring.*`**: `brand`, `error`. **`color.effect.shadow.*`**: `xs`, `sm-01/02`, `md-01/02`, `lg-01/02/03`, `xl-01/02/03`, `2xl-01/02`, `3xl-01/02`, `skeumorphic-inner`, `skeumorphic-inner-border`, plus `portfolio-mockup.*`.
- **`color.alpha.*`**: `white-10…100`, `black-10…100` (opacity steps).
- **`color.utility.<hue>.*`**: tonal utility ramps for data-viz/badges — `gray`, `brand` (+ `brand.*-alt`), `error`, `warning`, `success`, `gray-blue`, `green`, `blue-light`, `blue`, `blue-dark`, `indigo`, `purple`, `fuchsia`, `pink`, `orange-dark`, `orange`, `yellow` (steps 50–900 / 50–700 depending on hue).

Example light-theme resolutions:
```
color.text.primary        = {color.gray.900}
color.text.secondary      = {color.gray.700}
color.bg.primary          = {color.base.white}
color.bg.primary-hover    = {color.gray.50}
color.bg.brand-solid      = (brand ramp via refs)
color.border.primary      = {color.gray.300}
color.border.secondary-alt= rgba(0, 0, 0, 0.08)
```

### 4.5 Layer 3 — Component tokens

`component.*` tokens live inside the semantic theme files (and/or the playground component-token CSS) and are merged into each theme block at build time. Defined component namespaces:
`component.button.*` (`primary-text`, `primary-icon`, `primary-border`, `primary-border-hover`, `primary-bg`, `primary-bg-hover`, `destructive-primary-bg`, `destructive-primary-bg-hover`, `destructive-primary-border`, `destructive-primary-border-hover`), `component.avatar.styles-bg-neutral`, `component.toggle.*` (`button-fg-disabled`, `border`, `slim-border-pressed`, …), `component.tooltip.*` (`text`, `supporting-text`, `bg`), plus `featured-icon`, `file-type-icon`, `footer`, `tab`, `chart`, `slider`, `star-icon`, `screen-mockup`, `text-editor`, `app-store-badge`.

### 4.6 Build pipeline (`styleDictionary.config.mjs`)

The build is a custom Node script (run with `node styleDictionary.config.mjs`), **not** the default SD CLI. Behavior to replicate exactly:

1. **Brand discovery:** read every directory under `tokens/brand/` → list of brands.
2. **Custom name transform `name/pea`:** builds the CSS var name. Rules:
   - Drop leading `color` segment (`color.text.primary` → `text-primary`).
   - Drop leading `typography`, `spacing`, `radius`, `width` segments.
   - Keep `size`, `ref`, `container` prefixes.
   - Negative numeric segments `-1_6` → `neg1_6`.
   - Lowercase, replace non `[a-z0-9_-]` with `-`, collapse repeats, trim trailing `-`.
   - Final name: `` `${brand}-${name}` `` → output as `--pea-...`? **Note:** prefix is the brand (`pea`), so vars read `--pea-text-primary`. (For `brand-x`, names are still emitted under the same consuming convention; the brand selector in the CSS scopes them.)
3. **Custom value transform `size/px`:** adds `px` to `radius`, `spacing`, `width`, `container`, and typography `font-size`/`line-height`/`letter-spacing`. Never adds units to `font-family`, `font-weight`, or primitive `size`. `0` stays `"0"`; values rounded to 2 decimals.
4. **Transform group `pea/css`** = `["attribute/cti", "name/pea", "size/px", "color/css"]`.
5. **Custom format `css/vars`:** emits `  --<name>: <val>;` lines, re-applying the unitless/px logic.
6. **Per brand**, build:
   - `primitive.css` from `primitive/**` + `brand/<brand>/primitive.json` + `brand/<brand>/refs.json` (excluding `/semantic/`).
   - `semantic-<theme>.css` for each of `light`, `dark`, `high-contrast` (filtered to that theme file).
7. **Merge** into `build/css/<brand>/tokens.css`:
   ```css
   /* LAYER 1: PRIMITIVE */
   :root { …primitive vars… }
   /* LAYER 2: SEMANTIC */
   :root[data-brand="<brand>"][data-theme="light"] { …semantic + component… }
   :root[data-brand="<brand>"][data-theme="dark"] { … }
   :root[data-brand="<brand>"][data-theme="high-contrast"] { … }
   ```
   Component tokens are scraped from `projects/playground/public/tokens/<brand>/tokens.css` (regex per theme block) and appended into the matching theme.
8. **Typography utility classes** → `build/css/<brand>/typography.css`. Generated scales (each emits `font-family`, `font-size`, `line-height`, `letter-spacing`):
   - `display-2xl…display-xs` (uses `font-family-display`), letter-spacing tightens at large sizes (`tightest`/`tighter`/`tight`/`normal`).
   - `title-xl…title-xs` (display family, text sizes).
   - `body-xl…body-xs` and `text-xl…text-xs` (uses `font-family-body`).
   - Class name pattern: `.pea-typescale-<name>`.
   - Font-weight utilities: `.pea-font-normal|medium|semibold|bold` → `font-weight: var(--pea-font-weight-*)`.
9. Build scripts (`base/package.json`):
   ```
   gen:tokens   = npx tsx tools/transTokens.ts        # Figma export → tokens/*.json
   build:tokens = gen:tokens && node styleDictionary.config.mjs
   copy:dist    = copy build/css → dist/css
   build:ts     = tsc -p tsconfig.build-lib.json       # compile ThemeProvider + enums
   build        = build:tokens && copy:dist && rm build && build:ts
   ```
   `tools/transTokens.ts` normalizes a raw Figma token export (`figma/update2.json`, W3C `$value`/`$type` leaves) into the flat `tokens/*.json` files, sanitizing keys (preserving negative numeric keys) and rewriting `{ref}` paths.

### 4.7 `@pea-ds/base` package exports

```jsonc
"exports": {
  ".": { "types": "./dist/types/index.d.ts", "import": "./dist/index.js", "default": "./dist/index.js" },
  "./tokens.css":       "./dist/css/pea/tokens.css",
  "./tokens/pea":       "./dist/css/pea/tokens.css",
  "./tokens/brand-x":   "./dist/css/brand-x/tokens.css",
  "./typography.css":   "./dist/css/pea/typography.css",
  "./typography/pea":   "./dist/css/pea/typography.css",
  "./typography/brand-x":"./dist/css/brand-x/typography.css"
}
```
Peer deps: `react>=19`, `react-dom>=19`, `tsx^4.21`. The JS entry (`src/index.ts`) only exports the ThemeProvider + enums:
```ts
export * from './providers/ThemeProvider';
export * from './enum/brand';
export * from './enum/enum';
```

---

## 5. Theming Runtime (`@pea-ds/base`)

### 5.1 Enums (`src/enum/enum.ts`)
```ts
export enum ThemeEnum { Light = "light", Dark = "dark", HighContrast = "high-contrast" }
export enum Brand { Pea = "pea", BrandX = "brand-x" }
```
`src/enum/brand.ts`:
```ts
import { Brand, ThemeEnum } from "./enum";
export const BRAND = Brand.Pea;
export const DEFAULT_THEME: ThemeEnum = ThemeEnum.Light;
```

### 5.2 ThemeProvider (`src/providers/ThemeProvider.tsx`)

A client component (`'use client'`) that manages theme state and writes `data-brand` / `data-theme` attributes onto `:root`, which activates the matching semantic CSS block.

```ts
export type Theme = 'light' | 'dark' | 'high-contrast';

interface ThemeContextType {
  theme: Theme;
  brand: string;
  setTheme: (theme: Theme) => void;
  toggleTheme: () => void;
}

interface ThemeProviderProps {
  children: React.ReactNode;
  brand?: string;        // default 'pea'
  defaultTheme?: Theme;  // default 'light'
  storageKey?: string;   // default 'pea-theme'
}
```

**Required behavior:**
- On mount: read `localStorage[storageKey]`; if valid (`light|dark|high-contrast`) use it, else fall back to `window.matchMedia('(prefers-color-scheme: dark)')` → `dark`/`light`.
- Use a `mounted` flag to avoid SSR hydration mismatch (don't apply stored theme until after mount).
- `setTheme(theme)`: update state, persist to localStorage, set `document.documentElement` attributes `data-brand={brand}` and `data-theme={theme}`.
- `toggleTheme()`: cycle/swap themes.
- Expose via context; ship a `useTheme()` hook that throws if used outside the provider.

### 5.3 Consumer setup
```tsx
import '@pea-ds/base/tokens.css';
import '@pea-ds/base/typography.css';
import { ThemeProvider } from '@pea-ds/base';

<ThemeProvider brand="pea" defaultTheme="light">
  <App />
</ThemeProvider>
```

---

## 6. Components

**Shared conventions for ALL components:**
- File starts with `"use client";` then `import * as React from "react";`.
- Exported as a named `const` arrow function; set `Component.displayName`.
- Props type exported alongside (`<Name>Props`, size unions, etc.).
- Size/variant config is a top-of-file lookup object (`SIZE` / `TOKEN` / `VARIANT`) mapping the size/variant union → concrete style values. **Replicate these tables exactly.**
- Colors come from `var(--pea-...)`; never hardcode hex in components (shadows are the only place literal rgba fallbacks appear, always as the 2nd arg of `var(...)`).
- Controlled/uncontrolled: `const isControlled = controlledProp !== undefined; const [internal, setInternal] = useState(default); const value = isControlled ? controlledProp : internal;`
- Focus ring pattern (applied on `:focus` via React `focused` state → boxShadow):
  `0 0 0 2px var(--pea-bg-primary), 0 0 0 4px var(--pea-effect-focus-ring-brand)` (use `-error` ring for destructive/error).
- IDs via `React.useId()`.

---

### 6.1 Button — `@pea-ds/button`

```ts
export type ButtonVariant =
  | "primary" | "secondary" | "tertiary"
  | "primary-destructive" | "secondary-destructive" | "tertiary-destructive"
  | "link-color" | "link-gray";
export type ButtonSize = "sm" | "md" | "lg" | "xl";
export type ButtonShape = "square" | "round";

export type ButtonProps = {
  variant?: ButtonVariant;     // default "primary"
  size?: ButtonSize;           // default "md"
  shape?: ButtonShape;         // default "square"
  isDisabled?: boolean;        // default false
  isLoading?: boolean;         // default false
  iconOnly?: boolean;          // default false
  leadingIcon?: React.ReactNode;
  trailingIcon?: React.ReactNode;
  children?: React.ReactNode;
  onClick?: React.MouseEventHandler<HTMLButtonElement>;
  type?: "button" | "submit" | "reset"; // default "button"
  className?: string;
};
```

**SIZE table** (`h`=height px, `px`/`py`=padding, `icon`=icon px, `p`=icon-only padding, `radius`=`var(--pea-rounded-md)` for all; typography is a utility class):
| size | h | px | py | typographyClass | gap | icon | p |
|---|---|---|---|---|---|---|---|
| sm | 36 | 12 | 8 | `text-sm` + `font-semibold` | `space-1` | 20 | 8 |
| md | 40 | 14 | 10 | `text-sm` + `font-semibold` | `space-1` | 20 | 10 |
| lg | 44 | 16 | 10 | `text-md` + `font-semibold` | `space-1_5` | 20 | 12 |
| xl | 48 | 18 | 12 | `text-md` + `font-semibold` | `space-1_5` | 20 | 14 |

**VARIANT table** — each variant defines: `bg`, `color`, `iconColor`, `border`, `hoverBg`, `hoverBorder`, `hoverColor`, `hoverIconColor`, `disabledColor`, `disabledIconColor`, `disabledBorder`, `disabledBg`, `focusRing`. Key mappings:
- **primary**: bg `--pea-component-button-primary-bg`, text `--pea-component-button-primary-text`, border `--pea-component-button-primary-border`, hoverBg `--pea-component-button-primary-bg-hover`, focusRing `--pea-effect-focus-ring-brand`.
- **secondary**: bg `--pea-bg-primary`, color `--pea-text-secondary`, iconColor `--pea-fg-quaternary`, border `--pea-border-primary`, hoverBg `--pea-bg-primary-hover`.
- **tertiary**: bg transparent, color `--pea-text-tertiary`, border transparent, hoverBg `--pea-bg-primary-hover`.
- **primary-destructive**: bg `--pea-component-button-destructive-primary-bg`, border `--pea-component-button-destructive-primary-border`, hoverBg `…-bg-hover`, focusRing `--pea-effect-focus-ring-error`.
- **secondary-destructive**: bg `--pea-bg-primary`, color `--pea-text-error-primary`, border `--pea-border-error-subtle`, hoverBg `--pea-bg-error-primary`, focusRing error.
- **tertiary-destructive**: transparent bg, color `--pea-text-error-primary`, hoverBg `--pea-bg-error-primary`, focusRing error.
- **link-color**: transparent, color `--pea-text-brand-secondary`, iconColor `--pea-fg-brand-secondary-alt`, hover underlines, hoverColor `--pea-text-brand-secondary-hover`.
- **link-gray**: transparent, color `--pea-text-tertiary`, hover underlines.
- All `disabledColor`=`--pea-fg-disabled`, `disabledIconColor`=`--pea-fg-disabled-subtle`, `disabledBg`=`--pea-bg-disabled` (solid variants) / transparent (link/tertiary).

**Rendering rules:**
- Renders a `<button type={type} disabled={isDisabled||isLoading}>`.
- `display:inline-flex; align/justify center; gap`. Height = `t.h` (auto for link or iconOnly). Padding from SIZE; `0` for link variants; `t.p` all sides for iconOnly.
- `borderRadius`: `9999px` when `shape="round"`, else `t.radius`; link variants use `--pea-rounded-xs`.
- Border: `none` if transparent/disabled-link; else `1px solid <border|hoverBorder>`.
- Text/icon color resolves through disabled → loading → hover → base precedence; icon color is tracked **separately** from text.
- Focus → boxShadow ring (variant focusRing). `transition` ~0.2s on bg/border/color/text-decoration. `cursor: not-allowed` when disabled/loading. `whiteSpace: nowrap`, `userSelect: none`.
- **Loading state:** render an inline SVG `<Spinner>` (animated via `@keyframes pea-spin` → 360° rotate, 0.75s linear infinite) + the literal text `"Submitting..."` (hidden when `iconOnly`). `aria-busy={isLoading}`.
- Icons wrapped in `<span aria-hidden style={{display:inline-flex; flexShrink:0; color:iconColor}}>`.
- Set `aria-disabled`, and `tabIndex=-1` when disabled/loading. Class = `${typographyClass} ${className}`.

> `ButtonSplit` exists in the package as a WIP/demo (a pink-styled stub) and is **not** part of the public export (`index.ts` only does `export * from "./Button"`). Treat it as internal.

---

### 6.2 Checkbox — `@pea-ds/checkbox`

```ts
export type CheckboxSize = "sm" | "md";
export type CheckboxProps = {
  isChecked?: boolean;          // controlled
  defaultChecked?: boolean;     // default false
  isIndeterminate?: boolean;    // default false
  isDisabled?: boolean;         // default false
  size?: CheckboxSize;          // default "sm"
  label?: React.ReactNode;
  hint?: React.ReactNode;
  onChange?: (checked: boolean) => void;
  className?: string;
};
```
**TOKEN table:**
| size | boxSize | borderRadius | iconSize | gap | labelHintGap | labelClass | hintClass |
|---|---|---|---|---|---|---|---|
| sm | 16 | `rounded-xs` | 10 | `space-2` | 0 | `text-sm`+`font-medium` | `text-sm`+`font-normal` |
| md | 20 | `rounded-sm` | 12 | `space-3` | `space-0_5` | `text-md`+`font-medium` | `text-md`+`font-normal` |

**Behavior / styling:**
- A visually-hidden native `<input type="checkbox">` (opacity 0, absolutely positioned, `appearance:none`) overlaid on a styled `<span>` box; keeps native a11y + keyboard.
- `isActive = checked || isIndeterminate`.
- Box border: active → `1px solid transparent` (or `--pea-border-disabled` when disabled+active); inactive → `1px solid --pea-border-primary` (or `--pea-border-disabled` when disabled).
- Box bg: disabled → `--pea-bg-disabled-subtle`; active → `--pea-bg-brand-solid`; else transparent.
- Icon color `--pea-fg-white` (disabled `--pea-fg-disabled-subtle`).
- Focus ring boxShadow (brand). `opacity:0.4` + `cursor:not-allowed` when disabled.
- Icons: **CheckIcon** (SVG check path `M1 4L3.5 6.5L9 1`, stroke 1.5, round caps) when checked; **IndeterminateIcon** (horizontal bar `M1 1H9`) when indeterminate.
- Set `aria-checked` = `"mixed"` when indeterminate else boolean; set DOM `el.indeterminate` via ref.
- If `label`/`hint`: wrap in `<label>` with `display:inline-flex; align-items:flex-start; gap`. Label color `--pea-text-secondary`, hint color `--pea-text-tertiary`. Box gets `marginTop: space-0_5` to align with first text line. If no label/hint, return the bare box.

---

### 6.3 Input — `@pea-ds/input`

```ts
export type InputSize = "sm" | "md";
export type InputProps = {
  value?: string; defaultValue?: string;   // controlled / uncontrolled
  placeholder?: string;
  label?: React.ReactNode; hint?: React.ReactNode; error?: React.ReactNode;
  isDisabled?: boolean;     // default false
  isRequired?: boolean;     // default false — shows "*" after label
  size?: InputSize;         // default "sm"
  leadingIcon?: React.ReactNode; trailingIcon?: React.ReactNode;
  type?: "text" | "email" | "password";    // default "text"
  validate?: boolean;       // validate on blur
  customValidation?: (value: string) => string | null;
  onChange?: (value: string) => void;
  onBlur?: () => void; onFocus?: () => void;
  onValidate?: (isValid: boolean, errorMessage?: string) => void;
  className?: string;
};
```
**TOKEN table:**
| size | height | px | py | radius | iconSize | inputClass | labelClass/hintClass | labelHintGap |
|---|---|---|---|---|---|---|---|---|
| sm | 24 | 12 | 8 | `rounded-md` | 20 | `text-md`+`font-normal` | `text-sm` (medium/normal) | `space-1_5` |
| md | 24 | 14 | 10 | `rounded-md` | 20 | `text-md`+`font-normal` | `text-sm` (medium/normal) | `space-1_5` |

**Validation behavior:**
- `shouldValidate = validate || type === "email"`.
- Email regex: `^(?!.*\.\.)(?!.*\.$)[a-zA-Z0-9._%+-]+@[a-zA-Z0-9-]+(\.[a-zA-Z]{2,})+$` → message `"Please enter a valid email address"`.
- `customValidation` (if provided) returns an error string or `null`, takes precedence over email check.
- Validation runs on **blur** (`runValidation`); empty value = valid/no error. Fires `onValidate(isValid, message?)`.
- `displayError = error || (shouldValidate && validationError)`; clears the internal validation error as the user types.
- Error state shows destructive styling (error border/ring `--pea-effect-focus-ring-error`, error text `--pea-text-error-primary`).
- `isRequired` appends a `*` after the label. Leading/trailing icon slots. Focus ring (brand or error). Disabled greys the field and blocks changes.

---

### 6.4 Radio & RadioGroup — `@pea-ds/radio`

**Radio** (`Radio.tsx`):
```ts
export type RadioSize = "sm" | "md";
export type RadioProps = {
  isChecked?: boolean; defaultChecked?: boolean;  // default false
  isDisabled?: boolean; size?: RadioSize;          // default "sm"
  label?: React.ReactNode; hint?: React.ReactNode;
  value?: string; name?: string;
  onChange?: (e) => void; className?: string;
};
```
**TOKEN table:**
| size | boxSize | dotSize | gap | labelHintGap | labelClass | hintClass |
|---|---|---|---|---|---|---|
| sm | 16 | 6 | `space-2` | 0 | `text-sm`+`font-medium` | `text-sm`+`font-normal` |
| md | 20 | 8 | `space-3` | `space-0_5` | `text-md`+`font-medium` | `text-md`+`font-normal` |

Circular box (`border-radius: full`), hidden native `<input type="radio">`, brand fill + white dot when selected, brand focus ring, same label/hint layout & disabled treatment as Checkbox.

**RadioGroup** (`RadioGroup.tsx`):
```ts
export type RadioGroupOption = { value: string; label?: React.ReactNode; hint?: React.ReactNode; isDisabled?: boolean; };
export type RadioGroupProps = {
  value?: string; defaultValue?: string;   // default ""
  options: RadioGroupOption[];              // required
  name?: string; size?: RadioSize;          // default "sm"
  isDisabled?: boolean;                     // default false
  direction?: "vertical" | "horizontal";    // default "vertical"
  onChange?: (value: string) => void;
  className?: string;
};
```
- `role="radiogroup"`. Generates a shared `name` via `React.useId()` when none passed.
- Controlled by `value`, else internal state seeded from `defaultValue`.
- Renders one `<Radio>` per option; `isChecked = option.value === selected`; per-option `isDisabled` OR group `isDisabled`. Layout direction = flex column/row.

---

### 6.5 Toggle — `@pea-ds/toggle`

```ts
export type ToggleSize = "sm" | "md";
export type ToggleProps = {
  isChecked?: boolean; defaultChecked?: boolean;
  isDisabled?: boolean; size?: ToggleSize;   // default "md"
  label?: React.ReactNode; hint?: React.ReactNode;
  onChange?: (checked: boolean) => void; className?: string;
};
```
**TOKEN table** (track dimensions in px):
| size | trackW | trackH | thumbSize | thumbOffsetLeft | thumbOffsetRight | gap | labelHintGap |
|---|---|---|---|---|---|---|---|
| sm | 36 | 20 | 16 | 0 | 4 | `space-2` | 0 |
| md | 44 | 24 | 20 | 2 | 5 | `space-3` | `space-0_5` |

**Styling:**
- Track: `padding: space-0_5; border-radius: full`. Bg: disabled → `--pea-bg-disabled`; checked → `--pea-bg-brand-solid` (hover `--pea-bg-brand-solid-hover`); off → `--pea-bg-tertiary`. Border mirrors (disabled `--pea-border-disabled`, off `--pea-border-primary`).
- Thumb: `border-radius: full`, bg `--pea-fg-white` (disabled `--pea-component-toggle-button-fg-disabled`), drop shadow `0 1px 3px 0 var(--pea-effect-shadow-sm-01, rgba(10,13,18,.10)), 0 1px 2px -1px var(--pea-effect-shadow-sm-02, rgba(10,13,18,.10))`. Slides between left/right offsets via transform on checked.
- Brand focus ring boxShadow. Label/hint layout identical to Checkbox (label `--pea-text-secondary`, hint `--pea-text-tertiary`, box `marginTop: space-0_5`).

---

### 6.6 Tooltip — `@pea-ds/tooltip`

```ts
export type TooltipAlign = "start" | "center" | "end";
export type TooltipPlacement = "top" | "bottom" | "left" | "right";
export type TooltipProps = {
  content: React.ReactNode;                  // required
  placement?: TooltipPlacement;              // default "top"
  supportingText?: React.ReactNode;
  align?: TooltipAlign;                       // default "center"
  showArrow?: boolean;                        // default true
  forceVisible?: boolean;                     // default false
  children: React.ReactNode;                  // the trigger
  className?: string;
};
```
**Behavior / styling:**
- Wrapper `position: relative; display: inline-flex`; shows tooltip on hover/focus (`visible` state, seeded from `forceVisible`).
- Bubble: bg `--pea-component-tooltip-bg`, text `--pea-component-tooltip-text`, `border-radius: rounded-md`, padding `space-2 space-3`, `maxWidth: 320`, typography `text-xs`+`font-medium`, shadow lg (`0 12px 16px -4px …lg-01, 0 4px 6px -2px …lg-02, 0 2px 2px -1px …lg-03`).
- `supportingText` renders below content (`text-xs`+`font-medium`, color `--pea-component-tooltip-supporting-text`, `marginTop: space-0_5`).
- **Positioning** is computed from `placement` × `align`: 12px offset from the trigger (`calc(100% + 12px)`); `align` anchors the cross-axis (`start`/`center`/`end` via left/top % + translate).
- **Arrow** (`showArrow`): a `ARROW_SIZE = 6`px CSS triangle (borders) colored `--pea-component-tooltip-bg`, placed on the opposite side of `placement`.

---

### 6.7 Avatar & AvatarLabelGroup — `@pea-ds/avatar`

**Avatar** (`Avatar.tsx`):
```ts
export type AvatarVariant = "image" | "placeholder" | "text";
export type AvatarSize = "xs" | "sm" | "md" | "lg" | "xl";
export type AvatarProps = {
  variant?: AvatarVariant;  // default "text"
  size?: AvatarSize;        // default "md"
  src?: string;             // image URL (variant="image")
  alt?: string;             // default ""
  text?: string;            // default "WD" — shows first char, uppercased
  className?: string;
};
```
**AVATAR_SIZE table:**
| size | diameter | border | fontSize | iconPx |
|---|---|---|---|---|
| xs | 24px | 0.5px | `font-size-text-xs` | 12 |
| sm | 32px | 0.75px | `font-size-text-xs` | 16 |
| md | 40px | 1px | `font-size-text-sm` | 20 |
| lg | 48px | 1px | `font-size-text-md` | 24 |
| xl | 56px | 1px | `font-size-text-lg` | 28 |

**AVATAR_VARIANT table:**
| variant | background | color |
|---|---|---|
| image | `--pea-utility-brand-100` | transparent |
| placeholder | `--pea-component-avatar-styles-bg-neutral` | `--pea-text-quaternary` |
| text | `--pea-utility-brand-100` | `--pea-utility-brand-800` |

**Styling:** circular (`border-radius: full`), `border: <border> solid rgba(0,0,0,0.08)`, `overflow:hidden`, `box-sizing:border-box`, `font-family: body`, `font-weight: semibold`, `line-height: 1`. `role="img"`, `aria-label` = alt (image) / text (text) / `"user avatar"` (placeholder).
- **image**: layered fill + clipped `<img>` (object-position offsets `left:-26.72%`, `width/height:154.93%` to center-crop). Falls back to a built-in figma asset URL when `src` is absent.
- **placeholder**: inline `UserIcon` SVG (silhouette path) sized `iconPx`.
- **text**: first character of `text`, uppercased.

**AvatarLabelGroup** (`AvatarLabelGroup.tsx`):
```ts
export type AvatarLabelGroupSize = "sm" | "md" | "lg" | "xl";
export type AvatarLabelGroupProps = {
  src?: string;
  name: string;            // required — bold display name
  subtitle?: string;       // email / secondary line
  size?: AvatarLabelGroupSize;
  statusIcon?: boolean;    // status dot
  className?: string;
};
```
**LABEL_SIZE_CONFIG** (avatarSize, typography, gap):
| size | avatarSize | nameClass | subtitleClass | gap |
|---|---|---|---|---|
| sm | sm | `text-sm`+`semibold` | `text-sm` | `space-2` (8px) |
| md | md | `text-sm`+`semibold` | `text-sm` | `space-3` (12px) |
| lg | lg | `text-md`+`semibold` | `text-md` | `space-3` (12px) |
| xl | xl | `text-lg`+`semibold` | `text-lg` | `space-4` (16px) |

Renders `<Avatar>` + a stacked name/subtitle block; optional status dot. (Some prop docs in source are in Thai — behavior unchanged.)

---

### 6.8 Navigation — `@pea-ds/navigation` (preview)

Version `0.1.2-preview…`. WIP package (`src/ui/`, `dd.tsx`, dual `index.ts`/`index.js`). Not yet stabilized — treat as experimental; do not rely on its API.

---

## 7. Storybook

Config in `.storybook/main.ts`. Framework `@storybook/react-vite`. Story globs:
```
../projects/**/src/**/*.stories.@(js|jsx|mjs|ts|tsx)
../projects/playground/app/**/*.stories.@(ts|tsx)
../projects/playground/app/**/*.mdx
```
Addons: `@storybook/addon-vitest`, `@storybook/addon-a11y`, `@storybook/addon-docs`, `@storybook/addon-onboarding`. `core.disableTelemetry: true`. Static dir maps `projects/playground/public/tokens` → `/tokens`. Each component ships a `.stories.tsx` that doubles as its test target.

---

## 8. Testing

**Vitest 4 + Playwright** browser runner (`vitest.config.js`):
- Uses `@storybook/addon-vitest/vitest-plugin` → stories run as tests in a real Chromium browser (`headless`).
- Coverage provider `v8`, reporters `text` + `html` → `./coverage`, includes `projects/{button,checkbox,radio,toggle,tooltip,input}/src/**/*.tsx`, excludes `*.stories.tsx` and `index.ts`.
- Setup file `.storybook/vitest.setup.js`.

Commands: `npm test` (`vitest --run`), `npm run test:verbose`, `npm run test:coverage`.

---

## 9. Build, Dev & Scripts

Root `package.json` (`"type": "module"`, `"private": true`, workspaces = `projects/*`):
```
dev / dev:playground   → run playground (Next.js) dev server
build                  → build all workspaces (--if-present)
build:base|button|...  → build a single package
storybook              → storybook dev -p 6006
build-storybook        → storybook build -o storybook-static
test / test:verbose / test:coverage
clean                  → clean all workspaces
clean:all              → rm node_modules, .next, dist everywhere
```

**Build order matters:** build `@pea-ds/base` first (it generates the token CSS), then component packages (plain `tsc`). Component packages compile to `dist/` with `.d.ts` types in `dist/types/`.

**Toolchain versions:** TypeScript 5.9, React 19.2, Storybook 10.1, Vitest 4, Playwright 1.57, Style Dictionary 5.1, `@tokens-studio/sd-transforms` 2, Next 16.1, `next-themes` 0.4.

---

## 10. CI / Deployment

- **CI:** `.gitlab-ci.yml` (GitLab pipelines). Release flow bumps versions and updates `manifest/` (see git history — `ci/update-manifest-*`).
- **Containerized Storybook:** `Dockerfile` + `docker-compose.yml` build/serve the static Storybook.
- **Deploy manifests:** `manifest/{test,value,valueProd}.yml` (Helm-style values). Storybook is served behind **oauth2-proxy** with **Keycloak OIDC** (`OAUTH2_PROXY_PROVIDER: keycloak-oidc`, issuer `https://sso2.pea.co.th/realms/pea-users`). Staging URL: `https://design-dev.pea.co.th`. Keycloak setup documented in `KEYCLOAK_SETUP.md`; theme behavior in `THEME_SWITCHING_GUIDE.md`; test scenarios in `TEST_CASES.md`.

---

## 11. Rebuild Checklist (order of operations)

1. Scaffold the npm-workspace monorepo (`projects/*`), root `package.json`, `tsconfig.base.json`, `vitest.config.js`, `.storybook/`.
2. Build `@pea-ds/base`:
   a. Author primitive token JSON (`size`, `spacing`, `radius`, `width`, `container`, `typography`, `colors`) exactly per §4.2.
   b. Author brand ramps + refs for `pea` and `brand-x` (§4.3).
   c. Author semantic `light/dark/high-contrast.json` covering all paths in §4.4.
   d. Author component tokens (§4.5).
   e. Implement `styleDictionary.config.mjs` with the custom `name/pea` + `size/px` transforms, `css/vars` format, multi-brand/multi-theme merge, and typography-class generator (§4.6).
   f. Implement `ThemeProvider` + `useTheme` + enums (§5). Wire package `exports` (§4.7).
3. Build each component package against the CSS-variable contract, replicating the SIZE/TOKEN/VARIANT tables and behaviors in §6 verbatim. Add `.stories.tsx` per component.
4. Wire Storybook (§7) and Vitest/Playwright (§8).
5. Verify: every component reads only `--pea-*` variables, supports controlled+uncontrolled, shows the standard focus ring, and renders correctly across all three themes × both brands.
