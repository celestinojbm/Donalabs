import type { Metadata } from "next"
import { ActivityIcon, DatabaseIcon, ServerIcon, UsersIcon } from "lucide-react"

import { PageHeader } from "@/components/page-header"
import { DashboardChart } from "@/components/demos/dashboard-chart"
import { StatCard } from "@donalabs/ui/components/composite/stat-card"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@donalabs/ui/components/table"
import { Badge } from "@donalabs/ui/components/badge"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@donalabs/ui/components/card"

export const metadata: Metadata = { title: "Dashboard example" }

const RECENT_EVENTS = [
  { service: "n8n", event: "Workflow \"nightly-backup\" completed", time: "2m ago", status: "success" },
  { service: "Cal.com", event: "New booking: Product demo", time: "18m ago", status: "success" },
  { service: "Plausible", event: "Traffic spike detected on /pricing", time: "1h ago", status: "info" },
  { service: "Vaultwarden", event: "Admin login from new device", time: "3h ago", status: "warning" },
] as const

export default function DashboardPage() {
  return (
    <div className="space-y-8">
      <PageHeader
        title="Dashboard example"
        description="A realistic composition of the primitives above — the sidebar shell, StatCard, Chart, and Table — assembled into the kind of screen most DonaLabs projects will actually ship."
      />

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="Active services"
          value={7}
          icon={ServerIcon}
          description="All services reporting healthy"
        />
        <StatCard
          label="Requests today"
          value={12480}
          change={8.2}
          icon={ActivityIcon}
        />
        <StatCard
          label="Storage used"
          suffix=" GB"
          value={34}
          change={-2.1}
          icon={DatabaseIcon}
        />
        <StatCard
          label="Team members"
          value={12}
          icon={UsersIcon}
        />
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Requests &amp; errors</CardTitle>
          <CardDescription>Last 7 days, across every service.</CardDescription>
        </CardHeader>
        <CardContent>
          <DashboardChart />
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Recent activity</CardTitle>
          <CardDescription>Latest events across the platform.</CardDescription>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Service</TableHead>
                <TableHead>Event</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="text-right">When</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {RECENT_EVENTS.map((row) => (
                <TableRow key={row.event}>
                  <TableCell className="font-medium">{row.service}</TableCell>
                  <TableCell className="text-muted-foreground">{row.event}</TableCell>
                  <TableCell>
                    <Badge
                      variant={row.status === "warning" ? "destructive" : "secondary"}
                    >
                      {row.status}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-right text-muted-foreground">{row.time}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  )
}
