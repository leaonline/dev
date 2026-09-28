import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "lea.online Developer Docs",
  description: "The development guide and docs for lea.online system",
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Guide', link: '/guide/getting_started' }
    ],

    sidebar: [
      {
        text: 'Guide',
        items: [
          { text: 'Getting started', link: '/guide/getting_started' },
          { text: 'Deployment',
            items: [
              { text: 'How to deploy', link: '/guide/deployment/how_to' },
              { text: 'Server Security', link: '/guide/deployment/security' },
              { text: 'Backup', link: '/guide/deployment/backup' },
            ]
          }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/vuejs/vitepress' }
    ]
  }
})
