import {
  AlertTriangle,
  ArrowRight,
  Bell,
  Calendar,
  Check,
  ChevronDown,
  Copy,
  Download,
  Heart,
  Home,
  Layers,
  Lock,
  Mail,
  Menu,
  Search,
  Settings,
  Star,
  Trash2,
  User,
  X,
  type LucideIcon,
} from "lucide-react"

const ICONS: LucideIcon[] = [
  Home, Search, Bell, Mail, User, Settings, Star, Heart, Lock, Calendar,
  Layers, Menu, Check, X, ChevronDown, ArrowRight, Download, Copy, Trash2, AlertTriangle,
]

export function IconGrid() {
  return (
    <div className="grid grid-cols-5 gap-3 sm:grid-cols-10">
      {ICONS.map((Icon, i) => (
        <div
          key={i}
          className="flex aspect-square items-center justify-center rounded-lg border text-foreground/80 transition-colors hover:bg-muted"
        >
          <Icon className="size-5" strokeWidth={1.75} />
        </div>
      ))}
    </div>
  )
}
