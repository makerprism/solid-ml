/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./lib/**/*.{ml,mlx}",
    "./bin/**/*.{ml,mlx}",
    "./map/src/**/*.ts",
  ],
  // Safelist classes used in dynamically generated HTML (TypeScript/JavaScript)
  // that Tailwind's content scanner may not detect
  safelist: [
    // Calendar component classes
    'text-[10px]',
    'text-[9px]',
    'text-[8px]',
    'min-h-[100px]',
    'aspect-square',
    'bg-white/20',
    'h-24',
    'space-y-0.5',
    'leading-tight',
    'w-1.5',
    'h-1.5',
    // Event status colors (used in events-calendar.js)
    'bg-success-500',
    'bg-secondary-500',
    'bg-yellow-500',
    'bg-red-500',
    // Dark mode surface colors (used in dynamic JS content)
    'dark:bg-surface-900',
    'dark:bg-surface-850',
    'dark:bg-surface-800',
    'dark:shadow-retro-dark',
  ],
  darkMode: 'class',
  theme: {
    fontFamily: {
      'sans': ['Inter', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'sans-serif'],
      'heading': ['Rubik', 'sans-serif'],
    },
    extend: {
      colors: {
        'primary': {
          '50': '#fff7ed',
          '100': '#ffedd5',
          '200': '#fed7aa',
          '300': '#fdba74',
          '400': '#fb923c',
          '500': '#f97316',
          '600': '#ea580c',
          '700': '#c2410c',
          '800': '#9a3412',
          '900': '#7c2d12',
        },
        // Secondary: Blue - "today" markers, info states, secondary actions
        'secondary': {
          '50': '#eff6ff',
          '100': '#dbeafe',
          '200': '#bfdbfe',
          '300': '#93c5fd',
          '400': '#60a5fa',
          '500': '#3b82f6',
          '600': '#2563eb',
          '700': '#1d4ed8',
          '800': '#1e40af',
          '900': '#1e3a8a',
        },
        'success': {
          '50': '#ecfdf5',
          '100': '#d1fae5',
          '200': '#a7f3d0',
          '300': '#6ee7b7',
          '400': '#4ade80',
          '500': '#10b981',
          '600': '#059669',
          '700': '#047857',
          '800': '#065f46',
          '900': '#14532d',
        },
        'warning': {
          '500': '#f59e0b',
          '600': '#d97706',
        },
        // Dark mode surface colors - semantic tokens for dark backgrounds
        'surface': {
          '900': '#0a0a0a',  // Darkest - body, header, footer
          '850': '#0f0f0f',  // Form inputs
          '800': '#1a1a1a',  // Cards, menus, drawers
          '700': '#404040',  // Shadows in dark mode
        },
      },
      typography: {
        DEFAULT: {
          css: {
            '--tw-prose-body': '#1f2937',
            '--tw-prose-headings': '#111827',
            '--tw-prose-links': '#ea580c',
            '--tw-prose-bold': '#111827',
            '--tw-prose-code': '#c2410c',
            '--tw-prose-quotes': '#374151',
            '--tw-prose-invert-body': '#e5e7eb',
            '--tw-prose-invert-headings': '#ffffff',
            '--tw-prose-invert-links': '#fb923c',
            '--tw-prose-invert-bold': '#ffffff',
            '--tw-prose-invert-code': '#fdba74',
            '--tw-prose-invert-quotes': '#d1d5db',
          }
        }
      },
      // Retro shadow tokens for dark mode cards
      boxShadow: {
        'retro-dark': '6px 6px 0 #404040',
      }
    }
  },
  plugins: [
    require('@tailwindcss/typography'),
  ],
}
