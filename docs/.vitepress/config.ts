import { defineConfig } from 'vitepress'
// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Docs",
  description: "Product Deluxe Edition",
  head: [
    ['script', { src: 'https://player.vimeo.com/api/player.js' }]
  ],
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    nav: [
      { text: 'Home', link: '/' },
      { text: 'v1 vs v2', link: '/comparison' },
      { text: 'Mission', link: '/why' },
      { text: 'Architecture', link: '/architecture' },
      { text: 'Whitepaper', link: '/whitepaper' },
      { text: 'Changelog', link: '/changelog' },
      {
        text: 'Legacy (v1)',
        items: [
          { text: 'English (v1)', link: '/v1/index' },
          { text: 'Español (v1)', link: '/v1/es/index' }
        ]
      }
    ],

    sidebar: [
      {
        text: 'Mission Control',
        items: [
          { text: 'The Manifesto', link: '/manifesto' },
          { text: 'v2 Pitch Deck', link: '/pitch.html', target: '_blank' },
          { text: 'v1 vs v2 Comparison', link: '/comparison' },
          { text: '01 // Mission Control', link: '/guide/deploy' },
          { text: '02 // Blink Deluxe', link: '/guide/demo' },
          { text: '03 // Ghost Audit', link: '/reference/brief' },
          { text: '04 // Cinematic Demo', link: '/reference/design' }
        ]
      },
      {
        text: 'Legacy Docs (v1.0)',
        items: [
          { text: 'v1 Home', link: '/v1/index' },
          { text: 'Operation Guide', link: '/v1/docs/getting-started' },
          { text: 'Whitepaper', link: '/v1/docs/whitepaper' },
          { text: 'Mission', link: '/v1/docs/mission' }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/8ctag0n/xB77' }
    ]
  }
})
