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

import { submitContact, type ContactState } from "@/app/contact-action"

export function ContactForm() {
  const [state, action, pending] = useActionState<ContactState, FormData>(
    submitContact,
    null
  )
  const invalid = state?.status === "invalid"

  return (
    <form action={action} className="max-w-md" noValidate>
      <FieldGroup>
        <Field data-invalid={invalid || undefined}>
          <FieldLabel htmlFor="email">Correo</FieldLabel>
          <InputGroup>
            <InputGroupInput
              id="email"
              name="email"
              type="email"
              inputMode="email"
              autoComplete="email"
              placeholder="tu@correo.com"
              aria-invalid={invalid || undefined}
              required
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
            El envío todavía no tiene destino. Si lo pulsas, el correo se queda
            en esta página.
          </FieldDescription>
          {invalid ? (
            <FieldError>Ese correo no tiene forma de correo.</FieldError>
          ) : null}
        </Field>
        {state?.status === "pending" ? (
          <Alert>
            <AlertTitle>No se ha enviado</AlertTitle>
            <AlertDescription>
              Todavía no hay un buzón conectado. Tu correo no ha salido de esta
              página.
            </AlertDescription>
          </Alert>
        ) : null}
      </FieldGroup>
    </form>
  )
}
