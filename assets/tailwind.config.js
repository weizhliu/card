module.exports = {
  mode: 'jit',
  purge: [
    './js/**/*.js',
    '../lib/*_web/**/*.*ex'
  ],
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {
      spacing: {
        '22': '5.5rem',
      }
    },
  },
  variants: {
    extend: {},
  },
  plugins: [],
}
