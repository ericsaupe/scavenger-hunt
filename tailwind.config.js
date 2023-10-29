const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/components/**/*.html.erb',
    './app/components/**/*.rb',
  ],
  plugins: [
    require('@tailwindcss/forms'),
    require("daisyui"),
  ],
  theme: {
    extend: {
      colors: {
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
    },
    extend: {
      screens: {
        'print': {'raw': 'print'}
      }
    },
  },
  daisyui: {
    themes: ["cmyk", "halloween", "dark", "winter"],
  }
}
