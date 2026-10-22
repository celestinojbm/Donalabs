"use server"

import { deliverContact, type ContactState } from "@/lib/contact-submit"

function textField(formData: FormData, name: string) {
  const value = formData.get(name)
  if (value == null) return ""
  if (typeof value !== "string") return null
  return value
}

export async function submitContact(
  _previous: ContactState | null,
  formData: FormData
): Promise<ContactState> {
  const email = textField(formData, "email")
  const fax = textField(formData, "fax")
  if (email == null || fax == null) {
    return { status: "too-large" }
  }

  return deliverContact(
    { email, fax },
    { webhookUrl: process.env.LANDING_SHEETS_WEBHOOK_URL }
  )
}
