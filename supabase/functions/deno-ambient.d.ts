// Type declarations for Deno runtime and URL/npm imports in Supabase Edge Functions
// This file resolves IDE TypeScript language server squiggles when viewing Deno edge functions.

declare namespace Deno {
  export const env: {
    get(key: string): string | undefined;
    set(key: string, value: string): void;
  };
  export function serve(
    handler: (req: Request) => Promise<Response> | Response
  ): void;
}

declare module 'https://*' {
  const content: any;
  export default content;
  export const createClient: any;
  export type SupabaseClient = any;
  export type User = any;
  export const encodeBase64: (data: ArrayBuffer | Uint8Array) => string;
  export const decodeBase64: (b64: string) => Uint8Array;
}

declare module 'npm:*' {
  const content: any;
  export default content;
  export const argon2id: any;
}
