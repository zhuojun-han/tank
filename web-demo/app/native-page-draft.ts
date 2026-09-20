type FieldDraft = { key: string; value: string; checked?: boolean };
type Field = HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement;
function fields(): Field[] {
  return (Array.from(document.querySelectorAll('.sheet input, .sheet textarea, .sheet select, .kh-titration input')) as unknown as Field[])
    .filter(field => !['file', 'password', 'hidden'].includes(field.type));
}
function fieldKey(field: Field, index: number) {
  return `${index}:${field.name || field.getAttribute('aria-label') || field.type}`;
}
export function captureDraftFields(excludeSelector?: string): FieldDraft[] {
  return fields().filter(field => !excludeSelector || !field.closest(excludeSelector)).slice(0, 80).map((field, index) => ({
    key: fieldKey(field, index), value: field.value.slice(0, 2048),
    ...(field instanceof HTMLInputElement && ['checkbox', 'radio'].includes(field.type) ? { checked: field.checked } : {}),
  }));
}
export function restoreDraftFields(draft: unknown) {
  if (!Array.isArray(draft) || draft.length > 80) return;
  const restore = () => fields().forEach((field, index) => {
    // Calculated/locked values come from the plan, never replay their handlers.
    if (field.matches(':disabled') || ('readOnly' in field && field.readOnly)) return;
    const saved = draft.find((item: FieldDraft) => item && item.key === fieldKey(field, index));
    if (!saved || typeof saved.value !== 'string' || saved.value.length > 2048) return;
    if (field instanceof HTMLInputElement && ['checkbox', 'radio'].includes(field.type)) {
      if (typeof saved.checked === 'boolean' && field.checked !== saved.checked && (field.type === 'checkbox' || saved.checked)) field.click();
      return;
    }
    if (field.value === saved.value) return;
    const proto = field instanceof HTMLInputElement ? HTMLInputElement.prototype : field instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLSelectElement.prototype;
    Object.getOwnPropertyDescriptor(proto, 'value')?.set?.call(field, saved.value);
    field.dispatchEvent(new Event('input', { bubbles: true }));
    field.dispatchEvent(new Event('change', { bubbles: true }));
  });
  restore();
  // Restore fields revealed by a saved option after React has rendered them.
  requestAnimationFrame(restore);
}
