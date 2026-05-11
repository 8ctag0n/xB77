import { withMermaid } from 'vitepress-plugin-mermaid'

// https://vitepress.dev/reference/site-config
export default withMermaid({
  title: 'xB77',
  titleTemplate: ':title // xB77 Sovereign Commerce',
  description:
    'Sovereign commerce layer for autonomous agents on Solana — ZK-batched payments, shielded flows, mathematical audit.',
  lang: 'en-US',
  cleanUrls: true,
  appearance: 'force-dark',

  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' }],
    ['meta', { name: 'theme-color', content: '#c8ff2e' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:title', content: 'xB77 — Sovereign Commerce Layer' }],
    ['meta', { property: 'og:description', content: 'High-fidelity payments rail for autonomous agents on Solana. ZK-batched, shielded, mathematically auditable.' }],
    ['meta', { property: 'og:site_name', content: 'xB77' }],
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
    ['meta', { name: 'twitter:title', content: 'xB77 — Sovereign Commerce Layer' }],
    ['meta', { name: 'twitter:description', content: 'ZK-batched payments rail for autonomous agents on Solana.' }],
    ['script', { src: 'https://player.vimeo.com/api/player.js', defer: '' }],
  ],

  themeConfig: {
    logo: { src: '/favicon.svg', alt: 'xB77' },

    nav: [
      { text: 'Home', link: '/' },
      { text: 'Comparison', link: '/comparison' },
      { text: 'Mission', link: '/why' },
      { text: 'Architecture', link: '/architecture' },
      { text: 'Whitepaper', link: '/whitepaper' },
      { text: 'Changelog', link: '/changelog' },
      {
        text: 'Archive',
        items: [
          { text: 'v1 // Legacy Home', link: '/v1/index' },
          { text: 'v1 // Whitepaper', link: '/v1/docs/whitepaper' },
          { text: 'v1 // Mission', link: '/v1/docs/mission' },
        ],
      },
    ],

    sidebar: {
      '/v1/': [
        {
          text: 'Legacy Docs (v1.0)',
          items: [
            { text: '← Return to v2', link: '/' },
            { text: 'v1 Home', link: '/v1/index' },
            { text: 'Operation Guide', link: '/v1/docs/getting-started' },
            { text: 'Whitepaper', link: '/v1/docs/whitepaper' },
            { text: 'Mission', link: '/v1/docs/mission' },
            { text: 'English (Full)', link: '/v1/docs/index' },
            { text: 'Español (Full)', link: '/v1/es/index' },
          ],
        },
      ],
      '/': [
        {
          text: 'Mission Control',
          items: [
            { text: 'The Manifesto', link: '/manifesto' },
            { text: 'v2 Pitch Deck ↗', link: '/pitch.html', target: '_blank' },
            { text: 'v1 vs v2 Comparison', link: '/comparison' },
            { text: '01 // Mission Control', link: '/guide/deploy' },
            { text: '02 // Blink Deluxe', link: '/guide/demo' },
            { text: '03 // Ghost Audit', link: '/reference/brief' },
            { text: '04 // Cinematic Demo', link: '/reference/design' },
          ],
        },
        {
          text: 'Resources',
          items: [
            { text: 'Comparison Matrix', link: '/comparison' },
            { text: 'Architecture', link: '/architecture' },
            { text: 'Whitepaper', link: '/whitepaper' },
            { text: 'Changelog', link: '/changelog' },
            { text: 'Archive (v1 Legacy)', link: '/v1/index' },
          ],
        },
        {
          text: 'Reference',
          items: [
            { text: 'On-Chain Programs', link: '/reference/programs' },
            { text: 'Proof Format', link: '/reference/proof-format' },
            { text: 'Glossary', link: '/reference/glossary' },
          ],
        },
      ],
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/8ctag0n/xB77' },
    ],

    footer: {
      message: 'Sovereignty is not given, it is computed.',
      copyright: `© ${new Date().getFullYear()} xB77 Labs — Built for the machine economy.`,
    },

    search: {
      provider: 'local',
      options: {
        detailedView: true,
      },
    },

    outline: { level: [2, 3], label: 'On this page' },
    docFooter: { prev: 'Previous', next: 'Next' },
  },

  mermaid: {
    theme: 'dark',
    themeVariables: {
      darkMode: true,
      background: '#08080a',
      primaryColor: '#1a1a20',
      primaryTextColor: '#fffffa',
      primaryBorderColor: '#c8ff2e',
      lineColor: '#c8ff2e',
      secondaryColor: '#0e0e12',
      tertiaryColor: '#0a0a0e',
      edgeLabelBackground: '#0e0e12',
      clusterBkg: '#0e0e12',
      clusterBorder: 'rgba(200,255,46,0.3)',
      titleColor: '#c8ff2e',
      nodeTextColor: '#fffffa',
      activationBorderColor: '#00f0ff',
      activationBkgColor: '#0e0e12',
      sequenceNumberColor: '#c8ff2e',
      actorBkg: '#0e0e12',
      actorBorder: '#c8ff2e',
      actorTextColor: '#fffffa',
      actorLineColor: '#c8ff2e',
      signalColor: '#00f0ff',
      signalTextColor: '#fffffa',
      labelBoxBkgColor: '#0e0e12',
      labelBoxBorderColor: 'rgba(200,255,46,0.4)',
      labelTextColor: '#fffffa',
      loopTextColor: '#c8ff2e',
      noteBkgColor: '#0e0e12',
      noteBorderColor: 'rgba(0,240,255,0.4)',
      noteTextColor: '#fffffa',
    },
  },
  mermaidPlugin: {
    class: 'mermaid',
  },
})
