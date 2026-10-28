import {
  corners,
  cylinder,
  depthOf,
  iso,
  knurl,
  lineOnTop,
  pathOf,
  planOutline,
  ring,
  sideSeam,
  slabOf,
  topTicks,
  type Flat,
  type Plan,
  type Point3,
  type SolidPaths,
} from "../iso/iso-kit"
import { BAYS } from "./model"
import {
  BASE,
  BASE_H,
  BASE_Z,
  BUS,
  BUS_H,
  BUS_Z,
  CHASSIS_H,
  DRAWER_H,
  GATE,
  GATE_H,
  JACK,
  JACK_H,
  LABEL,
  P,
  PLUG_IN,
  PLUG_R,
  PLUG_Y,
  PUCK_H,
  PUCK_R,
  PUCK_X,
  PUCK_Y,
  RULER,
  SPOOL,
  bayCenter,
  chassisPlan,
  drawerPlan,
} from "./view"

const BUS_TOP = BUS_Z + BUS_H
const TOP = 0

export interface Screws {
  rings: string
  dots: Flat[]
}

function screws(plan: Plan, inset: number, z: number, radius = 2): Screws {
  const pts = corners(plan, inset)
  return {
    rings: pts.map(([x, y]) => ring(x, y, radius, z, P, 14)).join(""),
    dots: pts.map(([x, y]) => iso([x, y, z + 0.15], P)),
  }
}

function byDepth(points: Flat[]) {
  return [...points].sort(
    (a, b) => depthOf([a[0], a[1], 0], P) - depthOf([b[0], b[1], 0], P)
  )
}

export interface FootArt {
  key: string
  flange: SolidPaths
  foot: SolidPaths
}

export const feet: FootArt[] = byDepth(corners(BASE, 24)).map(([x, y]) => ({
  key: `foot-${x}-${y}`,
  flange: cylinder(x, y, 7.2, BASE_Z - 7, 3.2, P, 22),
  foot: cylinder(x, y, 5.2, BASE_Z - 3.8, 3.8, P, 22),
}))

export const baseSlab = slabOf(BASE, BASE_Z, BASE_H, P, 8, 1.5)
export const groove = planOutline(
  { x: BASE.x + 6, y: BASE.y + 6, w: BASE.w - 12, d: BASE.d - 12, r: 8 },
  TOP,
  P,
  8
)
export const baseScrews = screws(BASE, 12, TOP, 2.15)

export const labelSlab = slabOf(LABEL, TOP, 0.9, P, 4, 0.3)
export const labelScrews = screws(LABEL, 2.4, TOP + 0.9, 1.15)
export const labelRules = [28, 18, 22].map((length, index) =>
  lineOnTop(
    [LABEL.x + 4, LABEL.y + 4.2 + index * 3.1],
    [LABEL.x + 4 + length, LABEL.y + 4.2 + index * 3.1],
    TOP + 0.95,
    P
  )
)

export const rulerSlab = slabOf(RULER, TOP, 0.7, P, 3)
export const rulerTicks = topTicks(
  RULER.x + 4,
  RULER.x + RULER.w - 4,
  5,
  5,
  RULER.y + 0.7,
  TOP + 0.7,
  [1.8, 3.4],
  P
)

export const spoolFlangeBottom = cylinder(SPOOL.x, SPOOL.y, SPOOL.r, TOP, 1.6, P, 28, 0.3)
export const spoolBarrel = cylinder(SPOOL.x, SPOOL.y, SPOOL.r - 2.4, TOP + 1.6, 5.2, P, 28)
export const spoolFlangeTop = cylinder(
  SPOOL.x,
  SPOOL.y,
  SPOOL.r,
  TOP + 6.8,
  1.6,
  P,
  28,
  0.3
)
export const spoolBore = ring(SPOOL.x, SPOOL.y, 1.5, TOP + 8.4, P, 16)

export const busSlab = slabOf(BUS, BUS_Z, BUS_H, P, 4, 0.5)
export const busGroove = planOutline(
  { x: BUS.x + 2.2, y: BUS.y + 2.2, w: BUS.w - 4.4, d: BUS.d - 4.4, r: 0.6 },
  BUS_TOP,
  P,
  4
)

const postAt = (x: number) => ({
  collar: cylinder(x, BUS.y + BUS.d / 2, 4.2, TOP, 3.2, P, 20),
  post: cylinder(x, BUS.y + BUS.d / 2, 2.6, TOP + 3.2, BUS_Z - 3.2, P, 20),
})

export const busPosts = [BUS.x + 8, BUS.x + BUS.w - 8].map((x) => ({
  key: `post-${x}`,
  ...postAt(x),
}))

export const busStops = [BUS.x - 5, BUS.x + BUS.w].map((x) =>
  slabOf(
    { x, y: BUS.y - 1.4, w: 5, d: BUS.d + 2.8, r: 1 },
    BUS_Z,
    BUS_H + 2.2,
    P,
    3,
    0.4
  )
)

export interface BayArt {
  index: number
  chassis: SolidPaths
  seam: string
  vents: string[]
  screws: Screws
  lamp: SolidPaths
  lens: SolidPaths
  bezel: string
  neck: SolidPaths
  knob: SolidPaths
  knurl: string
  drawer: SolidPaths
  seal: string
  pull: SolidPaths
  collar: SolidPaths
  jumper: { d: string; from: Flat; to: Flat }
  tick: string
}

function wire(from: Point3, to: Point3) {
  const a = iso(from, P)
  const b = iso(to, P)
  return { d: pathOf([a, b]), from: a, to: b }
}

export const bays: BayArt[] = BAYS.map((_, index) => {
  const plan = chassisPlan(index)
  const drawer = drawerPlan(index)
  const cx = bayCenter(index)
  const lamp: Point3 = [cx - 5, plan.y + 8, CHASSIS_H]
  const knob: Point3 = [cx + 5, plan.y + plan.d - 9, CHASSIS_H]
  const vents = [0, 1, 2].map((slot) =>
    planOutline(
      {
        x: plan.x + 3.2,
        y: plan.y + 13 + slot * 3.2,
        w: 8,
        d: 1.05,
        r: 0.4,
      },
      CHASSIS_H,
      P,
      3
    )
  )
  const tap: Point3 = [cx, BUS.y + BUS.d / 2, BUS_TOP]
  const back: Point3 = [cx, plan.y, CHASSIS_H]
  return {
    index,
    chassis: slabOf(plan, TOP, CHASSIS_H, P, 5, 0.7),
    seam: sideSeam(plan, CHASSIS_H * 0.62, P, 5),
    vents,
    screws: screws(plan, 2.3, CHASSIS_H, 1.15),
    lamp: cylinder(lamp[0], lamp[1], 3.1, lamp[2], 3.1, P, 22, 0.35),
    lens: cylinder(lamp[0], lamp[1], 2, lamp[2] + 3.1, 1.25, P, 20, 0.25),
    bezel: ring(lamp[0], lamp[1], 2.45, lamp[2] + 3.1, P, 20),
    neck: cylinder(knob[0], knob[1], 1.55, knob[2], 1.3, P, 16),
    knob: cylinder(knob[0], knob[1], 2.7, knob[2] + 1.3, 3, P, 20, 0.3),
    knurl: knurl(knob[0], knob[1], 2.7, knob[2] + 1.5, knob[2] + 4, 16, P, 0.28),
    drawer: slabOf(drawer, TOP, DRAWER_H, P, 4, 0.45),
    seal: planOutline(
      {
        x: drawer.x + 1.6,
        y: drawer.y + 1.6,
        w: drawer.w - 3.2,
        d: drawer.d - 3.2,
        r: 1,
      },
      DRAWER_H,
      P,
      4
    ),
    pull: slabOf(
      {
        x: drawer.x + 4.5,
        y: drawer.y + drawer.d - 2.6,
        w: drawer.w - 9,
        d: 2.3,
        r: 0.6,
      },
      DRAWER_H - 0.4,
      2.6,
      P,
      3,
      0.3
    ),
    collar: cylinder(cx, BUS.y + BUS.d / 2, 2.15, BUS_TOP, 1.35, P, 16),
    jumper: wire(back, tap),
    tick: lineOnTop([cx, BUS.y + BUS.d], [cx, BUS.y + BUS.d - 3.4], BUS_TOP, P),
  }
})

export const jackSlab = slabOf(JACK, TOP, JACK_H, P, 4, 0.5)
export const jackBore = ring(
  JACK.x + 7,
  PLUG_Y,
  2.5,
  JACK_H,
  P,
  18
)
export const jackScrews = screws(JACK, 2.2, JACK_H, 1.05)

export const plugGrip = cylinder(PLUG_IN, PLUG_Y, PLUG_R, TOP, 8.5, P, 24, 0.4)
export const plugKnurl = knurl(PLUG_IN, PLUG_Y, PLUG_R, 2.2, 7.2, 18, P, 0.32)
export const plugNeck = slabOf(
  { x: PLUG_IN + 1.2, y: PLUG_Y - 2.1, w: 7.5, d: 4.2, r: 1.2 },
  2.4,
  4.2,
  P,
  4,
  0.3
)

export const puck = cylinder(PUCK_X, PUCK_Y, PUCK_R, TOP, PUCK_H, P, 24, 0.45)
export const puckCap = ring(PUCK_X, PUCK_Y, PUCK_R - 1.4, PUCK_H, P, 20)

export function leadOf(plugX = PLUG_IN) {
  return wire(
    [PUCK_X, PUCK_Y, PUCK_H],
    [plugX, PLUG_Y, 8.5]
  )
}

export const feed = wire(
  [JACK.x + JACK.w - 3, JACK.y + JACK.d / 2, JACK_H],
  [BUS.x + 4, BUS.y + BUS.d / 2, BUS_TOP]
)

const GATE_POST_Y = GATE.y + 18
const GATE_LEFT = GATE.x + 5
const GATE_RIGHT = GATE.x + GATE.w - 5

export const gatePosts = [GATE_LEFT, GATE_RIGHT].map((x) =>
  cylinder(x, GATE_POST_Y, 2.2, TOP, GATE_H, P, 16)
)
export const gateHead = slabOf(
  {
    x: GATE_LEFT - 2.2,
    y: GATE_POST_Y - 3,
    w: GATE_RIGHT - GATE_LEFT + 4.4,
    d: 6,
    r: 1,
  },
  GATE_H,
  2.8,
  P,
  3,
  0.35
)
export const gateBolt = slabOf(
  {
    x: GATE_LEFT,
    y: GATE_POST_Y + 2.2,
    w: GATE_RIGHT - GATE_LEFT,
    d: 3.3,
    r: 0.5,
  },
  7.2,
  2.5,
  P,
  3,
  0.3
)
export const gateHasp = slabOf(
  {
    x: GATE_LEFT + 4,
    y: GATE_POST_Y + 7.2,
    w: 14,
    d: 10,
    r: 1.3,
  },
  TOP,
  1.15,
  P,
  3,
  0.25
)
export const gateKey = ring(GATE_LEFT + 11, GATE_POST_Y + 12, 2.1, 1.15, P, 16)
export const gateScrews = screws(
  {
    x: GATE_LEFT + 4,
    y: GATE_POST_Y + 7.2,
    w: 14,
    d: 10,
    r: 1.3,
  },
  1.8,
  1.15,
  0.7
)

export const bead = cylinder(bayCenter(0), BUS.y + BUS.d / 2, 1.55, BUS_TOP + 1.35, 2.3, P, 16, 0.2)

export function beadShift(index: number) {
  return bayCenter(index) - bayCenter(0)
}
