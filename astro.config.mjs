// @ts-check
import { defineConfig } from 'astro/config';

import cloudflare from '@astrojs/cloudflare';

export default defineConfig({
  // deine echte Domain
  site: 'https://frauenverein-sarmenstorf.ch',
  output: 'server',
  adapter: cloudflare()
});