import type { Options } from "rehype-pretty-code";
import { bundledLanguages, getSingletonHighlighter, type ShikiTransformer } from "shiki";

type DiffLineKind = "add" | "remove" | undefined;

type RasterTransformerMetadata = {
  rasterDiffLines?: DiffLineKind[];
};

const rasterDiffTransformer: ShikiTransformer = {
  name: "raster-diff",
  preprocess(code, options) {
    const rawMeta = (options.meta as { __raw?: string } | undefined)?.__raw ?? "";
    if (!rawMeta.split(/\s+/).includes("diff")) return;

    const metadata = this.meta as RasterTransformerMetadata;
    const lines = code.split("\n");
    metadata.rasterDiffLines = lines.map((line) => {
      if (line.startsWith("+")) return "add";
      if (line.startsWith("-")) return "remove";
      return undefined;
    });

    return lines
      .map((line) => (/^[+\- ]/.test(line) ? line.slice(1) : line))
      .join("\n");
  },
  pre(hast) {
    const metadata = this.meta as RasterTransformerMetadata;
    if (metadata.rasterDiffLines) {
      hast.properties["data-raster-diff"] = "";
    }
  },
  line(hast, lineNumber) {
    const metadata = this.meta as RasterTransformerMetadata;
    const kind = metadata.rasterDiffLines?.[lineNumber - 1];
    if (!kind) return;

    hast.properties["data-diff-line"] = kind;
    hast.properties["data-diff-marker"] = kind === "add" ? "+" : "-";
  },
};

const getRasterHighlighter: NonNullable<Options["getHighlighter"]> = async (options) => {
  const highlighter = await getSingletonHighlighter(options);

  if (!highlighter.getLoadedLanguages().includes("metal")) {
    const cppRegistrations = (await bundledLanguages.cpp()).default;
    const cppLanguage = cppRegistrations.find((registration) => registration.name === "cpp");

    if (!cppLanguage) {
      throw new Error("Shiki's C++ grammar is unavailable for Metal highlighting.");
    }

    await highlighter.loadLanguage(
      ...cppRegistrations,
      {
        ...cppLanguage,
        name: "metal",
        aliases: [],
      },
    );
  }

  return highlighter;
};

export const codeHighlightOptions: Options = {
  theme: {
    light: "min-light",
    dark: "min-dark",
  },
  keepBackground: false,
  getHighlighter: getRasterHighlighter,
  transformers: [rasterDiffTransformer],
};
