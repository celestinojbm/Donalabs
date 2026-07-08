import type { Metadata } from "next"

import { PageHeader, Section } from "@/components/page-header"
import { ButtonDemo } from "@/components/demos/button-demo"
import { InputDemo } from "@/components/demos/input-demo"
import { FormDemo } from "@/components/demos/form-demo"
import { CardDemo } from "@/components/demos/card-demo"
import { TableDemo } from "@/components/demos/table-demo"
import { NavigationDemo } from "@/components/demos/navigation-demo"
import { OverlayDemo } from "@/components/demos/overlay-demo"
import { NotificationDemo } from "@/components/demos/notification-demo"

export const metadata: Metadata = { title: "Components" }

export default function ComponentsPage() {
  return (
    <div className="space-y-12">
      <PageHeader
        title="Components"
        description="Every component below is an owned file in packages/ui/src/components — vendored via the shadcn CLI (Radix primitives, Nova preset), not an opaque npm dependency. Edit it directly when a project needs something different."
      />
      <Section title="Buttons">
        <ButtonDemo />
      </Section>
      <Section
        title="Inputs"
        description="Input, input group, select, checkbox, switch."
      >
        <InputDemo />
      </Section>
      <Section
        title="Forms"
        description="react-hook-form + zod, composed with the Field primitive (Controller-based — shadcn's current recommended pattern)."
      >
        <FormDemo />
      </Section>
      <Section title="Cards">
        <CardDemo />
      </Section>
      <Section title="Tables">
        <TableDemo />
      </Section>
      <Section
        title="Navigation"
        description="Breadcrumb, navigation menu, tabs."
      >
        <NavigationDemo />
      </Section>
      <Section
        title="Dialogs, modals & dropdowns"
        description="Dialog, sheet, dropdown menu, popover, command palette, tooltip."
      >
        <OverlayDemo />
      </Section>
      <Section
        title="Notifications"
        description="Sonner toasts, inline alerts, and loading skeletons."
      >
        <NotificationDemo />
      </Section>
    </div>
  )
}
