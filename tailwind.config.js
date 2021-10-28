const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  mode: 'jit',
  purge: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js'
  ],
  plugins: [
    require('@tailwindcss/forms'),
  ],
  theme: {
    fontFamily: {
      'sans': ['Oswald', ...defaultTheme.fontFamily.sans],
      'serif': ['Bitter', ...defaultTheme.fontFamily.serif],
      'mono': [...defaultTheme.fontFamily.mono]
    }
  }
}
