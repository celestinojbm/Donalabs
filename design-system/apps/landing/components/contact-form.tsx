"use client"

import { useActionState } from "react"

import {
  Alert,
  AlertDescription,
  AlertTitle,
} from "@donalabs/ui/components/alert"
import {
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@donalabs/ui/components/field"
import {
  InputGroup,
  InputGroupAddon,
  InputGroupButton,
  InputGroupInput,
} from "@donalabs/ui/components/input-group"

import { submitContact } from "@/app/contact-action"
import type { ContactState } from "@/lib/contact-submit"

const FIELD_ERROR: Partial<Record<ContactState["status"], string>> = {
  invalid: "Ese correo no tiene forma de correo.",
  "too-large": "Ese envío es demasiado largo.",
}

export function ContactForm() {
  const [state, action, pending] = useActionState<
    ContactState | null,
    FormData
  >(submitContact, null)
  const fieldError = state ? FIELD_ERROR[state.status] : undefined

  return (
    <form action={action} className="relative max-w-md" noValidate>
      <div
        aria-hidden="true"
        className="absolute -left-[10000px] h-px w-px overflow-hidden"
      >
        <label htmlFor="fax">Fax</label>
        <input
          id="fax"
          name="fax"
          type="text"
          tabIndex={-1}
          autoComplete="off"
          defaultValue=""
        />
      </div>
      <FieldGroup>
        <Field data-invalid={fieldError ? true : undefined}>
          <FieldLabel htmlFor="email">Correo</FieldLabel>
          <InputGroup>
            <InputGroupInput
              id="email"
              name="email"
              type="email"
              inputMode="email"
              autoComplete="email"
              placeholder="tu@correo.com"
              aria-invalid={fieldError ? true : undefined}
              required
              maxLength={254}
            />
            <InputGroupAddon align="inline-end">
              <InputGroupButton
                type="submit"
                variant="default"
                size="sm"
                disabled={pending}
              >
                {pending ? "Enviando" : "Enviar"}
              </InputGroupButton>
            </InputGroupAddon>
          </InputGroup>
          <FieldDescription>
            Se anotan el correo, la fecha y el origen. No te escribo de vuelta.
          </FieldDescription>
          {fieldError ? <FieldError>{fieldError}</FieldError> : null}
        </Field>
        {state?.status === "unconfigured" ? (
          <Alert>
            <AlertTitle>No está configurado</AlertTitle>
            <AlertDescription>
              El envío no está configurado. Tu correo no ha salido de esta
              página.
            </AlertDescription>
          </Alert>
        ) : null}
        {state?.status === "failed" ? (
          <Alert variant="destructive">
            <AlertTitle>No se ha anotado</AlertTitle>
            <AlertDescription>
              No he podido guardarlo. Prueba otra vez dentro de un momento.
            </AlertDescription>
          </Alert>
        ) : null}
        {state?.status === "ok" ? (
          <Alert>
            <AlertTitle>Anotado</AlertTitle>
            <AlertDescription>Listo. Tu correo quedó anotado.</AlertDescription>
          </Alert>
        ) : null}
      </FieldGroup>
    </form>
  )
}
