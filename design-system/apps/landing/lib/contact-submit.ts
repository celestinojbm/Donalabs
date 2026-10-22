const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
const MAX_EMAIL = 254
const MAX_TRAP = 200
const MAX_URL = 2000
const MAX_HOPS = 5
const ORIGIN = "donalabs"

export type ContactStatus =
  "invalid" | "too-large" | "unconfigured" | "failed" | "ok"

export interface ContactState {
  status: ContactStatus
}

export interface ContactFields {
  email: string
  fax: string
}

export interface ContactDeps {
  webhookUrl: string | undefined
  now?: () => Date
  fetchImpl?: typeof fetch
}

function httpsUrl(value: string, base?: string) {
  try {
    const url = new URL(value, base)
    if (url.protocol !== "https:") return null
    if (url.username || url.password) return null
    if (url.toString().length > MAX_URL) return null
    return url.toString()
  } catch {
    return null
  }
}

function httpsWebhook(value: string | undefined) {
  const webhook = value?.trim() ?? ""
  if (!webhook) return null
  return httpsUrl(webhook)
}

export async function deliverContact(
  fields: ContactFields,
  deps: ContactDeps
): Promise<ContactState> {
  if (fields.email.length > MAX_EMAIL || fields.fax.length > MAX_TRAP) {
    return { status: "too-large" }
  }

  const email = fields.email.trim()
  if (!email || email.length > MAX_EMAIL || !EMAIL.test(email)) {
    return { status: "invalid" }
  }

  // Filled honeypot: do not store the address and do not explain why.
  if (fields.fax.trim() !== "") {
    return { status: "ok" }
  }

  const webhookUrl = httpsWebhook(deps.webhookUrl)
  if (!webhookUrl) {
    return { status: "unconfigured" }
  }

  const payload = {
    email,
    date: (deps.now ?? (() => new Date()))().toISOString(),
    origin: ORIGIN,
  }

  try {
    const accepted = await postJson(
      deps.fetchImpl ?? fetch,
      webhookUrl,
      JSON.stringify(payload)
    )
    return { status: accepted ? "ok" : "failed" }
  } catch {
    return { status: "failed" }
  }
}

// Apps Script web apps answer the first POST with 302 and drop the body if
// the client follows the spec and switches to GET. Re-send the same JSON.
async function postJson(
  fetchImpl: typeof fetch,
  webhookUrl: string,
  body: string
) {
  let url = webhookUrl
  for (let hop = 0; hop <= MAX_HOPS; hop++) {
    const response = await fetchImpl(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body,
      cache: "no-store",
      redirect: "manual",
      signal: AbortSignal.timeout(8000),
    })
    const location = response.headers.get("location")
    const redirecting = response.status >= 300 && response.status < 400
    await response.body?.cancel()
    if (!redirecting) return response.ok
    if (!location || hop === MAX_HOPS) return false
    const next = httpsUrl(location, url)
    if (!next) return false
    url = next
  }
  return false
}
