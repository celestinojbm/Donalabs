import { ArrowUpRightIcon, UsersIcon } from "lucide-react"

import {
  Card,
  CardAction,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@donalabs/ui/components/card"
import { Button } from "@donalabs/ui/components/button"
import { Avatar, AvatarFallback } from "@donalabs/ui/components/avatar"
import { Badge } from "@donalabs/ui/components/badge"

export function CardDemo() {
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <Card>
        <CardHeader>
          <CardTitle>Team members</CardTitle>
          <CardDescription>Everyone with access to this project.</CardDescription>
          <CardAction>
            <Badge variant="secondary">
              <UsersIcon className="size-3" /> 12
            </Badge>
          </CardAction>
        </CardHeader>
        <CardContent className="flex -space-x-2">
          {["AD", "BR", "CJ", "DK"].map((initials) => (
            <Avatar key={initials} className="border-2 border-background">
              <AvatarFallback>{initials}</AvatarFallback>
            </Avatar>
          ))}
        </CardContent>
        <CardFooter>
          <Button variant="outline" size="sm" className="w-full">
            Manage team
          </Button>
        </CardFooter>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Upgrade to Pro</CardTitle>
          <CardDescription>
            Unlock every service in the DonaLabs platform.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <p className="text-3xl font-semibold">
            $0<span className="text-base font-normal text-muted-foreground">/mo</span>
          </p>
          <p className="text-sm text-muted-foreground">Self-hosted — always free.</p>
        </CardContent>
        <CardFooter>
          <Button className="w-full">
            Get started <ArrowUpRightIcon />
          </Button>
        </CardFooter>
      </Card>

      <Card className="justify-center">
        <CardHeader>
          <CardTitle>Minimal card</CardTitle>
          <CardDescription>
            Just a header — cards are composed, not configured.
          </CardDescription>
        </CardHeader>
      </Card>
    </div>
  )
}
