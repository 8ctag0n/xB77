import { defineConfig } from 'vitepress'

export default defineConfig({
  base: '/xB77/',
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
            text: '03_INTEGRATIONS',
            items: [
              { text: 'Helius (RPC & DAS)', link: '/docs/integrations/helius' },
              { text: 'Noir (Agent Identity)', link: '/docs/integrations/noir' },
              { text: 'Light Protocol (Compression)', link: '/docs/integrations/light-protocol' },
              { text: 'ShadowWire (Shielded Rail)', link: '/docs/integrations/shadow-wire' },
              { text: 'Privacy Cash (Obfuscation)', link: '/docs/integrations/privacy-cash' },
              { text: 'Starpay (Fiat Bridge)', link: '/docs/integrations/starpay' },
              { text: 'Future (Arcium & Kamino)', link: '/docs/integrations/future-roadmap' }
            ]
          },
          {
            text: '04_ECOSYSTEM',
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
              { text: 'El Cerebro Autónomo (EN)', link: '/docs/architecture/autonomous-brain' },
              { text: 'Integración MCP (EN)', link: '/docs/architecture/mcp-integration' },
              { text: 'Diseño del Agente', link: '/es/docs/agent-design' },
              { text: 'Arquitectura Infra', link: '/es/docs/diagrams' },
              { text: 'Declaración de Misión', link: '/es/docs/mission' }
            ]
          },
          {
            text: '03_INTEGRACIONES',
            items: [
              { text: 'Helius (RPC & DAS)', link: '/es/docs/integrations/helius' },
              { text: 'Noir (Identidad)', link: '/es/docs/integrations/noir' },
              { text: 'Light Protocol (Compresión)', link: '/es/docs/integrations/light-protocol' },
              { text: 'ShadowWire (Riel Protegido)', link: '/es/docs/integrations/shadow-wire' },
              { text: 'Privacy Cash (Obfuscación)', link: '/es/docs/integrations/privacy-cash' },
              { text: 'Starpay (Puente Fiat)', link: '/es/docs/integrations/starpay' },
              { text: 'Futuro (Arcium y Kamino)', link: '/es/docs/integrations/future-roadmap' }
            ]
          },
          {
            text: '04_ECOSYSTEM',
            items: [
              { text: 'Libro Blanco', link: '/es/docs/whitepaper' },
              { text: 'Sponsor Alignment (EN)', link: '/docs/sponsors' }
            ]
          }
        ]
      }
    }
  },

  themeConfig: {
    socialLinks: [
      { icon: 'github', link: 'https://github.com/8ctag0n/xB77' }
    ],
    footer: {
      message: 'Built for the Solana Privacy Hackathon 2026',
      copyright: 'Copyright © 2026 xB77 Labs'
    }
  },
  appearance: 'auto'
})
