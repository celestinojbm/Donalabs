"use server"

export type ContactState = { status: "invalid" } | { status: "pending" } | null

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export async function submitContact(
  _previous: ContactState,
  formData: FormData
): Promise<ContactState> {
  const email = String(formData.get("email") ?? "").trim()

  if (email.length > 254 || !EMAIL.test(email)) {
    return { status: "invalid" }
  }

  // PENDING: no mail endpoint is configured.
  // Do not forward, store, or log the address.
  return { status: "pending" }
}
