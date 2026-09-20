/** Keep a confirmed UI transition authoritative while older writes drain. */
export function createDraftWriteGuard() {
  const guards = new Map<string, Set<(value: unknown) => unknown>>();
  return {
    protect(section: string, transform: (value: unknown) => unknown) {
      const sectionGuards = guards.get(section) ?? new Set<(value: unknown) => unknown>();
      sectionGuards.add(transform);
      guards.set(section, sectionGuards);
      return () => {
        sectionGuards.delete(transform);
        if (!sectionGuards.size) guards.delete(section);
      };
    },
    apply(section: string, value: unknown) {
      for (const transform of guards.get(section) ?? []) value = transform(value);
      return value;
    },
  };
}
