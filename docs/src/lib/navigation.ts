import {
  BookOpen,
  Boxes,
  Braces,
  Cpu,
  GitPullRequest,
  Wrench,
} from "lucide-react";

export type DocsTabId =
  | "start"
  | "framework"
  | "guides"
  | "reference"
  | "internals"
  | "contributing";

export type NavItem = {
  title: string;
  slug: string;
  badge?: string;
};

export type NavSection = {
  title: string;
  items: NavItem[];
};

export type DocsTab = {
  id: DocsTabId;
  title: string;
  shortTitle: string;
  description: string;
  icon: typeof BookOpen;
  sections: NavSection[];
};

export const docsTabs: DocsTab[] = [
  {
    id: "start",
    title: "Start",
    shortTitle: "Start",
    description: "Installation, a first render, the example apps, and migrating from MetalPetal.",
    icon: BookOpen,
    sections: [
      {
        title: "Getting started",
        items: [
          { title: "Introduction", slug: "start/overview" },
          { title: "Installation", slug: "start/installation" },
          { title: "First Pipeline", slug: "start/first-pipeline" },
          { title: "Examples", slug: "start/examples" },
        ],
      },
      {
        title: "From MetalPetal",
        items: [
          {
            title: "Migrating from MetalPetal",
            slug: "start/migrating-from-metalpetal",
            badge: "2.0",
          },
        ],
      },
    ],
  },
  {
    id: "framework",
    title: "Framework",
    shortTitle: "Framework",
    description: "Images, contexts, filters, render graphs, alpha, color, and HDR.",
    icon: Boxes,
    sections: [
      {
        title: "How Raster works",
        items: [
          { title: "Images & Promises", slug: "framework/images-promises" },
          { title: "Contexts & Rendering", slug: "framework/contexts-rendering" },
          { title: "Filters & Kernels", slug: "framework/filters-kernels" },
          { title: "Render Graphs & Caching", slug: "framework/render-graphs-caching" },
        ],
      },
      {
        title: "Color and alpha",
        items: [
          { title: "Alpha", slug: "framework/alpha" },
          { title: "Color & HDR", slug: "framework/color-hdr", badge: "Updated" },
        ],
      },
    ],
  },
  {
    id: "guides",
    title: "Guides",
    shortTitle: "Guides",
    description: "Image I/O, filter graphs, custom shaders, video, and performance.",
    icon: Wrench,
    sections: [
      {
        title: "Pipelines",
        items: [
          { title: "Image Input & Output", slug: "guides/image-io" },
          { title: "Filter Chains", slug: "guides/filter-chains" },
          { title: "Blending & Compositing", slug: "guides/blending-compositing" },
          { title: "Custom Filters", slug: "guides/custom-filters" },
        ],
      },
      {
        title: "Integrate",
        items: [
          { title: "Video & Pixel Buffers", slug: "guides/video-pixel-buffers" },
          { title: "Framework Interop", slug: "guides/framework-interop" },
          {
            title: "Core Image Metal Kernels",
            slug: "guides/core-image-metal-kernels",
          },
          { title: "Performance & Debugging", slug: "guides/performance-debugging" },
        ],
      },
    ],
  },
  {
    id: "reference",
    title: "Reference",
    shortTitle: "Reference",
    description: "Platforms, packages, public types, shader arguments, and built-in filters.",
    icon: Braces,
    sections: [
      {
        title: "Compatibility",
        items: [
          { title: "Platform Support", slug: "reference/platform-support" },
          { title: "Packages & Modules", slug: "reference/packages-modules" },
        ],
      },
      {
        title: "Types",
        items: [
          { title: "Public Types", slug: "reference/public-types" },
          { title: "Shader Arguments", slug: "reference/shader-arguments" },
          { title: "Built-in Filters", slug: "reference/built-in-filters" },
          { title: "Glossary", slug: "reference/glossary" },
        ],
      },
    ],
  },
  {
    id: "internals",
    title: "Inside Raster",
    shortTitle: "Internals",
    description: "Render evaluation, the optimizer, shader generation, resources, and concurrency.",
    icon: Cpu,
    sections: [
      {
        title: "Architecture",
        items: [
          { title: "Repository Map", slug: "internals/repository-map" },
          { title: "Promise Resolution", slug: "internals/promise-resolution" },
          { title: "Render Graph Optimizer", slug: "internals/render-graph-optimizer" },
          {
            title: "Pipelines & Argument Encoding",
            slug: "internals/pipelines-argument-encoding",
          },
          { title: "Shader Generation", slug: "internals/shader-generation" },
          { title: "Resources & Concurrency", slug: "internals/resources-concurrency" },
        ],
      },
    ],
  },
  {
    id: "contributing",
    title: "Contributing",
    shortTitle: "Contributing",
    description: "Local development, tests, generators, examples, releases, and support.",
    icon: GitPullRequest,
    sections: [
      {
        title: "Development",
        items: [
          { title: "Local Development", slug: "contributing/local-development" },
          { title: "Tests & CI", slug: "contributing/tests-ci" },
          { title: "Generated Sources", slug: "contributing/generated-sources" },
          { title: "Example Projects", slug: "contributing/example-projects" },
        ],
      },
      {
        title: "Releases and support",
        items: [
          { title: "Releases", slug: "contributing/releases" },
          { title: "Support & Security", slug: "contributing/support-security" },
        ],
      },
    ],
  },
];

export function getDocPath(slug: string) {
  return `/docs/${slug}`;
}

export function getFlatNavItems() {
  return docsTabs.flatMap((tab) =>
    tab.sections.flatMap((section) =>
      section.items.map((item) => ({
        ...item,
        tabId: tab.id,
        tabTitle: tab.title,
        sectionTitle: section.title,
      })),
    ),
  );
}

export function getTabForSlug(slug: string) {
  return (
    docsTabs.find((tab) =>
      tab.sections.some((section) => section.items.some((item) => item.slug === slug)),
    ) ?? docsTabs[0]
  );
}
