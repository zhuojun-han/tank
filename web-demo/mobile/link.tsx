import type { AnchorHTMLAttributes } from 'react';

// The static bundle has no Next router or server-prefetch endpoint.
export default function Link(props: AnchorHTMLAttributes<HTMLAnchorElement>) {
  return <a {...props} />;
}
