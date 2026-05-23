/** Normalize a version string into a ``vMAJOR.MINOR.PATCH`` tag form.
 *
 * Accepts PEP 440 / semver forms used in ``deeptutor/__version__.py`` and
 * GitHub release tags (``1.4.0``, ``v1.4.0``, ``1.4.0rc1``, ``v1.0.0-beta.4``)
 * while rejecting git-describe output like ``v1.2.3-5-gabc1234``.
 */
export function normalizeVersionTag(
  raw: string | null | undefined,
): string | null {
  const value = raw?.trim();
  if (!value) return null;
  const match = value.match(
    /^v?(\d+\.\d+\.\d+(?:(?:rc|a|b)\d+|\.dev\d+|\.post\d+|-[A-Za-z][0-9A-Za-z.-]*)?)$/,
  );
  return match ? `v${match[1]}` : null;
}

export type VersionSource = "git" | "env" | "unknown";

export interface ParsedBuild {
  tag: string;
  display: string;
  isDev: boolean;
  isDirty: boolean;
  commitsAhead: number;
  commit: string;
}

export function parseBuild(raw: string | null | undefined): ParsedBuild | null {
  if (!raw) return null;
  const tag = normalizeVersionTag(raw);
  if (!tag) return null;
  const isDev = raw.includes("-dev") || raw.includes("-beta") || raw.includes(".dev");
  return {
    tag,
    display: raw,
    isDev,
    isDirty: raw.includes("-dev") || raw.includes("dirty"),
    commitsAhead: 0,
    commit: "",
  };
}

export function unknownBuild(raw: string | null | undefined): ParsedBuild {
  const fallback = raw ?? "unknown";
  return {
    tag: fallback,
    display: fallback,
    isDev: true,
    isDirty: false,
    commitsAhead: 0,
    commit: "",
  };
}
