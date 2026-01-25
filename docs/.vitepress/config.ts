import { defineConfig } from 'vitepress'

export default defineConfig({
  title: "xB77 Infrastructure",
  description: "Autonomous Financial Operating System for AI Agents",
  themeConfig: {
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Guide', items: [
        { text: 'English', link: '/guide/GETTING_STARTED' },
        { text: 'Español', link: '/guide/GETTING_STARTED_ES' }
      ]},
      { text: 'Whitepaper', items: [
        { text: 'English', link: '/whitepaper/WHITEPAPER_EN' },
        { text: 'Español', link: '/whitepaper/WHITEPAPER_ES' }
      ]},
      { text: 'Architecture', items: [
        { text: 'English', link: '/architecture/DIAGRAMS' },
        { text: 'Español', link: '/architecture/DIAGRAMS_ES' }
      ]}
    ],

    sidebar: [
      {
        text: 'Getting Started (EN)',
        collapsed: true,
        items: [
          { text: 'Operation Guide', link: '/guide/GETTING_STARTED' },
          { text: 'Execution Modes', link: '/guide/MODES' },
          { text: 'Philosophy of Use', link: '/guide/PHILOSOPHY' }
        ]
      },
      {
        text: 'Guía de Inicio (ES)',
        collapsed: true,
        items: [
          { text: 'Guía de Operación', link: '/guide/GETTING_STARTED_ES' },
          { text: 'Modos de Ejecución', link: '/guide/MODES_ES' },
          { text: 'Filosofía de Uso', link: '/guide/PHILOSOPHY_ES' }
        ]
      },
      {
        text: 'Technical Deep Dive',
        items: [
          { text: 'Agent Design (EN)', link: '/explanations/AGENT_DESIGN' },
          { text: 'Diseño del Agente (ES)', link: '/explanations/AGENT_DESIGN_ES' },
          { text: 'Architecture (EN)', link: '/architecture/DIAGRAMS' },
          { text: 'Arquitectura (ES)', link: '/architecture/DIAGRAMS_ES' }
        ]
      },
      {
        text: 'Ecosystem',
        items: [
          { text: 'Use Cases', link: '/whitepaper/USE_CASES' },
          { text: 'Sponsor Alignment', link: '/ecosystem/SPONSORS' }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/xB77-labs' }
    ],

    footer: {
      message: 'Built for the Solana Privacy Hackathon 2026',
      copyright: 'Copyright © 2026 xB77 Labs'
    }
  },
  appearance: 'dark' // Force dark mode for institutional look
})
