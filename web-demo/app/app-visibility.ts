/** Native lifecycle can change before Android updates document.visibilityState. */
export function isAppVisible() {
  return document.visibilityState !== 'hidden'
    && document.documentElement.dataset.nativeLifecycle !== 'paused';
}

export function observeAppVisibility(refresh: () => void) {
  document.addEventListener('visibilitychange', refresh);
  window.addEventListener('lanjiao:lifecycle', refresh);
  return () => {
    document.removeEventListener('visibilitychange', refresh);
    window.removeEventListener('lanjiao:lifecycle', refresh);
  };
}
