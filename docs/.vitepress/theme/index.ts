// https://vitepress.dev/guide/custom-theme
import type { Theme } from 'vitepress'
import DefaultTheme from 'vitepress/theme'
import './style.css'
import './custom.css'
import TerminalDeluxe from './components/TerminalDeluxe.vue'
import TerminalCRT from './components/TerminalCRT.vue'

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component('TerminalDeluxe', TerminalDeluxe)
    app.component('TerminalCRT', TerminalCRT)
  },
} satisfies Theme
