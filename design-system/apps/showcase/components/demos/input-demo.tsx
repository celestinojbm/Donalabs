"use client"

import { SearchIcon } from "lucide-react"

import { Label } from "@donalabs/ui/components/label"
import { Input } from "@donalabs/ui/components/input"
import {
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
} from "@donalabs/ui/components/input-group"
import { Checkbox } from "@donalabs/ui/components/checkbox"
import { Switch } from "@donalabs/ui/components/switch"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@donalabs/ui/components/select"

export function InputDemo() {
  return (
    <div className="grid max-w-2xl gap-6 sm:grid-cols-2">
      <div className="space-y-2">
        <Label htmlFor="input-demo-text">Text input</Label>
        <Input id="input-demo-text" placeholder="Ada Lovelace" />
      </div>

      <div className="space-y-2">
        <Label htmlFor="input-demo-search">Input group</Label>
        <InputGroup>
          <InputGroupInput id="input-demo-search" placeholder="Search services..." />
          <InputGroupAddon>
            <SearchIcon />
          </InputGroupAddon>
        </InputGroup>
      </div>

      <div className="space-y-2">
        <Label htmlFor="input-demo-select">Select</Label>
        <Select defaultValue="vaultwarden">
          <SelectTrigger id="input-demo-select" className="w-full">
            <SelectValue placeholder="Choose a service" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="vaultwarden">Vaultwarden</SelectItem>
            <SelectItem value="calcom">Cal.com</SelectItem>
            <SelectItem value="plausible">Plausible</SelectItem>
            <SelectItem value="penpot">Penpot</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div className="flex flex-col justify-end gap-4">
        <div className="flex items-center gap-2">
          <Checkbox id="input-demo-checkbox" defaultChecked />
          <Label htmlFor="input-demo-checkbox">Accept terms</Label>
        </div>
        <div className="flex items-center gap-2">
          <Switch id="input-demo-switch" defaultChecked />
          <Label htmlFor="input-demo-switch">Enable notifications</Label>
        </div>
      </div>
    </div>
  )
}
