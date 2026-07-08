"use client"

import { Controller, useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { toast } from "sonner"

import { Button } from "@donalabs/ui/components/button"
import { Input } from "@donalabs/ui/components/input"
import { Textarea } from "@donalabs/ui/components/textarea"
import { Switch } from "@donalabs/ui/components/switch"
import {
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@donalabs/ui/components/field"

const schema = z.object({
  name: z.string().min(2, "Name must be at least 2 characters."),
  email: z.email("Enter a valid email address."),
  message: z.string().max(280, "Keep it under 280 characters.").optional(),
  notify: z.boolean(),
})

type FormValues = z.infer<typeof schema>

export function FormDemo() {
  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { name: "", email: "", message: "", notify: true },
  })

  function onSubmit(values: FormValues) {
    toast.success("Form submitted", {
      description: `${values.name} <${values.email}>`,
    })
  }

  return (
    <form onSubmit={form.handleSubmit(onSubmit)} className="max-w-md">
      <FieldGroup>
        <Controller
          name="name"
          control={form.control}
          render={({ field, fieldState }) => (
            <Field data-invalid={fieldState.invalid}>
              <FieldLabel htmlFor={field.name}>Name</FieldLabel>
              <Input {...field} id={field.name} aria-invalid={fieldState.invalid} placeholder="Ada Lovelace" />
              <FieldError errors={fieldState.error ? [fieldState.error] : []} />
            </Field>
          )}
        />
        <Controller
          name="email"
          control={form.control}
          render={({ field, fieldState }) => (
            <Field data-invalid={fieldState.invalid}>
              <FieldLabel htmlFor={field.name}>Email</FieldLabel>
              <Input {...field} id={field.name} type="email" aria-invalid={fieldState.invalid} placeholder="ada@donalabs.dev" />
              <FieldError errors={fieldState.error ? [fieldState.error] : []} />
            </Field>
          )}
        />
        <Controller
          name="message"
          control={form.control}
          render={({ field, fieldState }) => (
            <Field data-invalid={fieldState.invalid}>
              <FieldLabel htmlFor={field.name}>Message</FieldLabel>
              <Textarea {...field} id={field.name} placeholder="Optional" rows={3} />
              <FieldDescription>Max 280 characters.</FieldDescription>
              <FieldError errors={fieldState.error ? [fieldState.error] : []} />
            </Field>
          )}
        />
        <Controller
          name="notify"
          control={form.control}
          render={({ field }) => (
            <Field orientation="horizontal">
              <FieldLabel htmlFor={field.name}>Notify me about updates</FieldLabel>
              <Switch
                id={field.name}
                checked={field.value}
                onCheckedChange={field.onChange}
              />
            </Field>
          )}
        />
        <Button type="submit" className="w-fit">
          Submit
        </Button>
      </FieldGroup>
    </form>
  )
}
