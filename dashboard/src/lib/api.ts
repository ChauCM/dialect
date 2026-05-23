/// Typed thin wrappers around the dialect serve REST API. Mirrors the
/// shapes serialized in lib/server/serializers.dart.

export interface DialectConfig {
  source_locale: string;
  target_locales: string[];
  project_name: string;
  platforms: Record<string, { output: string; format: string; namespaces: string[] }>;
}

export interface StringEntry {
  key: string;
  namespace: string | null;
  source: string;
  translation: string | null;
  description: string | null;
  context: string | null;
  placeholders: Record<string, { type?: string; format?: string }>;
  locked: boolean;
  glossary_exempt: boolean;
  source_hash: string | null;
  current_source_hash: string;
  stale: boolean;
  missing: boolean;
}

export interface StringsPayload {
  locale: string;
  source_locale: string;
  entries: StringEntry[];
}

export interface GlossaryTerm {
  term: string;
  meaning: string;
  translations: Record<string, string>;
}

export interface GlossaryPayload {
  terms: GlossaryTerm[];
}

export interface StatusRow {
  locale: string;
  coverage: number;
  missing: number;
  stale: number;
  locked: number;
}

export interface StatusPayload {
  rows: StatusRow[];
}

async function get<T>(path: string): Promise<T> {
  const res = await fetch(path, { headers: { 'accept': 'application/json' } });
  if (!res.ok) throw new Error(`${path}: ${res.status} ${res.statusText}`);
  return res.json() as Promise<T>;
}

export function fetchConfig(): Promise<DialectConfig> {
  return get('/api/config');
}

export function fetchStrings(locale: string): Promise<StringsPayload> {
  return get(`/api/strings?locale=${encodeURIComponent(locale)}`);
}

export function fetchGlossary(): Promise<GlossaryPayload> {
  return get('/api/glossary');
}

export function fetchStatus(): Promise<StatusPayload> {
  return get('/api/status');
}

export interface PutStringBody {
  locale: string;
  value: string;
  locked?: boolean;
  glossary_exempt?: boolean;
}

export async function putString(key: string, body: PutStringBody): Promise<void> {
  const res = await fetch(`/api/strings/${encodeURIComponent(key)}`, {
    method: 'PUT',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const errBody = await res.json().catch(() => ({ error: res.statusText }));
    throw new Error((errBody as { error?: string }).error ?? res.statusText);
  }
}
