import { defineConfig } from 'vitepress'

export default defineConfig({
  title: "xB77 Infrastructure",
  description: "Autonomous Financial Operating System for AI Agents",
  themeConfig: {
    logo: '/logo.png', // Placeholder, podemos añadir uno luego
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Whitepaper', items: [
        { text: 'English', link: '/whitepaper/WHITEPAPER_EN' },
        { text: 'Español', link: '/whitepaper/WHITEPAPER_ES' }
      ]},
      { text: 'Architecture', link: '/architecture/DIAGRAMS' },
      { text: 'Ecosystem', link: '/ecosystem/SPONSORS' }
    ],

    sidebar: [
      {
        text: 'Introduction',
        items: [
          { text: 'The Vision', link: '/mission' },
          { text: 'Agent Design', link: '/explanations/AGENT_DESIGN' }
        ]
      },
      {
        text: 'Technical Docs',
        items: [
          { text: 'Whitepaper (EN)', link: '/whitepaper/WHITEPAPER_EN' },
          { text: 'Whitepaper (ES)', link: '/whitepaper/WHITEPAPER_ES' },
          { text: 'System Architecture', link: '/architecture/DIAGRAMS' }
        ]
      },
      {
        text: 'Business & Ecosystem',
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
