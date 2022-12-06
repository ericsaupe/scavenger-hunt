const defaultTheme = require('tailwindcss/defaultTheme')
const colors = require('tailwindcss/colors')

module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js'
  ],
  plugins: [
    require('@tailwindcss/forms'),
    require('tailwindcss-break')(),
  ],
  theme: {
    colors: {
      transparent: 'transparent',
      current: 'currentColor',
      black: colors.black,
      white: colors.white,
      gray: colors.neutral,
      indigo: colors.indigo,
      red: colors.rose,
      yellow: colors.amber,
      emerald: colors.emerald,
      green: colors.green,
      blue: colors.blue,
      purple: colors.purple,
      orange: colors.orange,
      pink: colors.pink,
      teal: colors.teal,
      'pantone': {
        'DEFAULT': '#BB2649',
        '50': '#EEABBA',
        '100': '#EA9AAD',
        '200': '#E47891',
        '300': '#DD5676',
        '400': '#D6345A',
        '500': '#BB2649',
        '600': '#8C1D37',
        '700': '#5E1325',
        '800': '#2F0A12',
        '900': '#000000'
      },
    },
    extend: {
      screens: {
        'print': {'raw': 'print'}
      }
    },
    fontFamily: {
      'sans': ['Oswald', ...defaultTheme.fontFamily.sans],
      'serif': ['Bitter', ...defaultTheme.fontFamily.serif],
      'mono': [...defaultTheme.fontFamily.mono]
    }
  }
}
