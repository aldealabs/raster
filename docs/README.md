# Raster Documentation

This directory is the Raster 2.x documentation site. It is a standalone Next.js and MDX application for people using the framework and for people contributing to it.

## Read the documentation in the repository

- [Introduction](content/docs/start/overview.mdx)
- [Installation](content/docs/start/installation.mdx)
- [First Pipeline](content/docs/start/first-pipeline.mdx)
- [Migrating from MetalPetal](content/docs/start/migrating-from-metalpetal.mdx)
- [Framework Concepts](content/docs/framework/images-promises.mdx)
- [Guides](content/docs/guides/image-io.mdx)
- [API Reference](content/docs/reference/public-types.mdx)
- [Inside Raster](content/docs/internals/repository-map.mdx)
- [Contributing](content/docs/contributing/local-development.mdx)

Alternatively,

## Read the documentation site

[Raster documentation](https://raster.aldealabs.com)

## Run the site locally

```bash
npm ci
npm run dev
```

Open `http://localhost:3000`. The production site is a static export:

```bash
npm run check
```

That command checks the content graph, lints the application, and writes the static site to `out/`.

## Add or change a page

Pages live under `content/docs/` and use MDX with `title` and `description` frontmatter. Add every page to `src/lib/navigation.ts`. That file controls order, search grouping, and previous/next links.

When writing: name the topic, explain what it is, then show the smallest example.
