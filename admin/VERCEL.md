# Vercel hosting

Production: https://hymnora-studio-admin.vercel.app

Project identity is retained in `vercel-project.json`; the packaging script restores the link in a fresh checkout.

The dashboard authenticates with Supabase Auth and server-side admin membership. The built frontend contains the public client configuration only. Drafts, recordings and source PDFs remain in Supabase.

For the initial local CLI deployment, run `npm run build`, `npm run prepare:vercel`, then run `npx vercel deploy .local/vercel-deploy --prod --yes` while signed into the correct Vercel account. This staging directory contains only the built frontend and hosting configuration. Its ignored `.vercel/project.json` keeps the account/project link for subsequent deployments.

For a future Git deployment, select `admin` as the project root in the Hymnora repository. The tracked `vercel.json` declares Vite, `npm run build` and `dist`. The `.vercelignore` excludes private local content and SQL setup. Do not upload PDFs or catalogue JSON into public frontend assets.

Sign in again on the hosted domain with the approved Supabase Auth account. Password sign-in does not use an OAuth redirect. Never add a service-role key to the client configuration.

Verified production state READY, hosted login and compiled asset HTTP 200, no browser console errors. Requests for local environment files, owner SQL, backend SQL and catalogue JSON returned 404. The earlier Sites registration is retained as historical configuration; the active admin host is Vercel.
