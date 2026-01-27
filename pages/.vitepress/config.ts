import { defineConfig } from 'vitepress'

export default defineConfig({
  title: "xB77 Infrastructure",
  description: "Autonomous Financial Operating System for AI Agents",
  
  head: [
    ['link', { rel: 'preconnect', href: 'https://fonts.googleapis.com' }],
    ['link', { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' }],
    ['link', { rel: 'stylesheet', href: 'https://fonts.googleapis.com/css2?family=Rajdhani:wght@300;400;500;600;700&family=Share+Tech+Mono&family=Fira+Code:wght@300;400;500&display=swap' }],
    ['link', { rel: 'stylesheet', href: 'https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1' }]
  ],

  locales: {
    root: {
      label: 'English',
      lang: 'en',
      themeConfig: {
        nav: [
          { text: 'HOME', link: '/' },
          { text: 'OPERATIONS', link: '/docs/getting-started' },
          { text: 'WHITE_PAPER', link: '/docs/whitepaper' },
          { text: 'INFRA_MAP', link: '/docs/diagrams' }
        ],
        sidebar: [
          {
            text: '01_GETTING_STARTED',
            items: [
              { text: 'Operation Guide', link: '/docs/getting-started' },
              { text: 'Hub Overview', link: '/docs/guide/hub-overview' },
              { text: 'Execution Modes', link: '/docs/modes' },
              { text: 'Philosophy of Use', link: '/docs/philosophy' }
            ]
          },
          {
            text: '02_TECHNICAL_DEEP_DIVE',
            items: [
              { text: 'The Autonomous Brain', link: '/docs/architecture/autonomous-brain' },
              { text: 'MCP Integration', link: '/docs/architecture/mcp-integration' },
              { text: 'Agent Design', link: '/docs/agent-design' },
              { text: 'Infra Architecture', link: '/docs/diagrams' },
              { text: 'Mission Statement', link: '/docs/mission' }
            ]
          },
          {
            text: '03_ECOSYSTEM',
            items: [
              { text: 'Sponsor Alignment', link: '/docs/sponsors' }
            ]
          }
        ]
      }
    },
    es: {
      label: 'Español',
      lang: 'es',
      link: '/es/',
      themeConfig: {
        nav: [
          { text: 'INICIO', link: '/es/' },
          { text: 'OPERACIONES', link: '/es/docs/getting-started' },
          { text: 'LIBRO_BLANCO', link: '/es/docs/whitepaper' },
          { text: 'MAPA_INFRA', link: '/es/docs/diagrams' }
        ],
        sidebar: [
          {
            text: '01_PRIMEROS_PASOS',
            items: [
              { text: 'Guía de Operación', link: '/es/docs/getting-started' },
              { text: 'Modos de Ejecución', link: '/es/docs/modes' },
              { text: 'Filosofía de Uso', link: '/es/docs/philosophy' }
            ]
          },
          {
            text: '02_INMERSIÓN_TÉCNICA',
            items: [
              { text: 'El Cerebro Autónomo', link: '/docs/architecture/autonomous-brain' },
              { text: 'Integración MCP', link: '/docs/architecture/mcp-integration' },
              { text: 'Diseño del Agente', link: '/es/docs/agent-design' },
              { text: 'Arquitectura Infra', link: '/es/docs/diagrams' }
            ]
          }
        ]
      }
    }
  },

  themeConfig: {
    socialLinks: [
      { icon: 'github', link: 'https://github.com/xB77-labs' }
    ],
    footer: {
      message: 'Built for the Solana Privacy Hackathon 2026',
      copyright: 'Copyright © 2026 xB77 Labs'
    }
  },
  appearance: 'dark'
})