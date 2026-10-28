import assert from "node:assert/strict"
import { describe, it } from "node:test"

import { deliverContact } from "./contact-submit.ts"

const WEBHOOK = "https://script.google.com/macros/s/example/exec"
const NOW = () => new Date("2026-10-22T18:00:00.000Z")

function capture(status = 200) {
  const calls: { url: string; init: RequestInit }[] = []
  const fetchImpl: typeof fetch = async (url, init) => {
    calls.push({ url: String(url), init: init ?? {} })
    return new Response("ok", { status })
  }
  return { calls, fetchImpl }
}

describe("deliverContact", () => {
  it("rejects an email that is not an email and does not call the webhook", async () => {
    const { calls, fetchImpl } = capture()
    const result = await deliverContact(
      { email: "no-es", fax: "" },
      { webhookUrl: WEBHOOK, fetchImpl }
    )
    assert.equal(result.status, "invalid")
    assert.equal(calls.length, 0)
  })

  it("rejects an oversized field and does not call the webhook", async () => {
    const { calls, fetchImpl } = capture()
    const result = await deliverContact(
      { email: `${"a".repeat(250)}@ejemplo.com`, fax: "" },
      { webhookUrl: WEBHOOK, fetchImpl }
    )
    assert.equal(result.status, "too-large")
    assert.equal(calls.length, 0)
  })

  it("drops a filled honeypot without posting", async () => {
    const { calls, fetchImpl } = capture()
    const result = await deliverContact(
      { email: "ada@ejemplo.com", fax: "http://spam.example" },
      { webhookUrl: WEBHOOK, fetchImpl, now: NOW }
    )
    assert.equal(result.status, "ok")
    assert.equal(calls.length, 0)
  })

  it("says the send is not configured when the webhook is missing", async () => {
    const { calls, fetchImpl } = capture()
    const result = await deliverContact(
      { email: "ada@ejemplo.com", fax: "" },
      { webhookUrl: "  ", fetchImpl }
    )
    assert.equal(result.status, "unconfigured")
    assert.equal(calls.length, 0)
  })

  it("refuses a webhook that is not https", async () => {
    const { calls, fetchImpl } = capture()
    const result = await deliverContact(
      { email: "ada@ejemplo.com", fax: "" },
      {
        webhookUrl: "http://script.google.com/macros/s/example/exec",
        fetchImpl,
      }
    )
    assert.equal(result.status, "unconfigured")
    assert.equal(calls.length, 0)
  })

  it("posts the email, an ISO date and the origin", async () => {
    const { calls, fetchImpl } = capture()
    const result = await deliverContact(
      { email: "  ada@ejemplo.com  ", fax: "" },
      { webhookUrl: WEBHOOK, fetchImpl, now: NOW }
    )
    assert.equal(result.status, "ok")
    assert.equal(calls.length, 1)
    const call = calls[0]
    assert.ok(call)
    assert.equal(call.url, WEBHOOK)
    assert.equal(call.init.method, "POST")
    assert.equal(call.init.redirect, "manual")
    const headers = new Headers(call.init.headers)
    assert.equal(headers.get("content-type"), "application/json")
    assert.deepEqual(JSON.parse(String(call.init.body)), {
      email: "ada@ejemplo.com",
      date: "2026-10-22T18:00:00.000Z",
      origin: "donalabs",
    })
  })

  it("reposts the JSON when the webhook redirects", async () => {
    const calls: { url: string; init: RequestInit }[] = []
    const landed = "https://script.googleusercontent.com/macros/echo"
    const fetchImpl: typeof fetch = async (url, init) => {
      calls.push({ url: String(url), init: init ?? {} })
      if (calls.length === 1) {
        return new Response(null, {
          status: 302,
          headers: { location: landed },
        })
      }
      return new Response("ok", { status: 200 })
    }
    const result = await deliverContact(
      { email: "ada@ejemplo.com", fax: "" },
      { webhookUrl: WEBHOOK, fetchImpl, now: NOW }
    )
    assert.equal(result.status, "ok")
    assert.equal(calls.length, 2)
    assert.equal(calls[1]?.url, landed)
    assert.equal(calls[1]?.init.method, "POST")
    assert.deepEqual(JSON.parse(String(calls[1]?.init.body)), {
      email: "ada@ejemplo.com",
      date: "2026-10-22T18:00:00.000Z",
      origin: "donalabs",
    })
  })

  it("does not follow a redirect that leaves https", async () => {
    const calls: { url: string }[] = []
    const fetchImpl: typeof fetch = async (url) => {
      calls.push({ url: String(url) })
      return new Response(null, {
        status: 302,
        headers: { location: "http://evil.example/hook" },
      })
    }
    const result = await deliverContact(
      { email: "ada@ejemplo.com", fax: "" },
      { webhookUrl: WEBHOOK, fetchImpl, now: NOW }
    )
    assert.equal(result.status, "failed")
    assert.equal(calls.length, 1)
  })

  it("reports a failure when the webhook does not accept the row", async () => {
    const { fetchImpl } = capture(500)
    const result = await deliverContact(
      { email: "ada@ejemplo.com", fax: "" },
      { webhookUrl: WEBHOOK, fetchImpl, now: NOW }
    )
    assert.equal(result.status, "failed")
  })

  it("reports a failure when the webhook cannot be reached", async () => {
    const fetchImpl: typeof fetch = async () => {
      throw new Error("offline")
    }
    const result = await deliverContact(
      { email: "ada@ejemplo.com", fax: "" },
      { webhookUrl: WEBHOOK, fetchImpl, now: NOW }
    )
    assert.equal(result.status, "failed")
  })
})
