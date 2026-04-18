declare const Deno: {
  serve: (
    handler: (req: Request) => Response | Promise<Response>,
  ) => void;
  env: {
    get: (name: string) => string | undefined;
  };
};

declare module 'npm:@supabase/supabase-js@2' {
  export function createClient(
    supabaseUrl: string,
    supabaseKey: string,
    options?: unknown,
  ): any;
}
