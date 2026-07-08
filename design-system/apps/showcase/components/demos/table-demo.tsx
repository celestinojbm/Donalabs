import {
  Table,
  TableBody,
  TableCaption,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@donalabs/ui/components/table"
import { Badge } from "@donalabs/ui/components/badge"

const SERVICES = [
  { name: "Vaultwarden", role: "Secrets manager", status: "Healthy" },
  { name: "Cal.com", role: "Scheduling", status: "Healthy" },
  { name: "Plausible", role: "Analytics", status: "Healthy" },
  { name: "Penpot", role: "Design platform", status: "Healthy" },
  { name: "n8n", role: "Automation", status: "Healthy" },
  { name: "Open WebUI", role: "AI interface", status: "Healthy" },
] as const

export function TableDemo() {
  return (
    <Table>
      <TableCaption>Shared services running on the DonaLabs platform.</TableCaption>
      <TableHeader>
        <TableRow>
          <TableHead>Service</TableHead>
          <TableHead>Role</TableHead>
          <TableHead className="text-right">Status</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {SERVICES.map((service) => (
          <TableRow key={service.name}>
            <TableCell className="font-medium">{service.name}</TableCell>
            <TableCell className="text-muted-foreground">{service.role}</TableCell>
            <TableCell className="text-right">
              <Badge variant="outline" className="text-emerald-600 dark:text-emerald-400">
                {service.status}
              </Badge>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}
