const defaultTheme = require('tailwindcss/defaultTheme')

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
