import {
  boxCorners,
  fitProjection,
  type Plan,
  type Point3,
  type Projection,
} from "../iso/iso-kit"

export const WIDTH = 680
export const HEIGHT = 430
export const AZIMUTH = 50
export const ELEVATION = 32

export const BASE: Plan = { x: -18, y: -172, w: 308, d: 220, r: 12 }
export const BASE_Z = -11
export const BASE_H = 11

export const BUS: Plan = { x: 36, y: -150, w: 188, d: 11, r: 1.4 }
export const BUS_Z = 13
export const BUS_H = 6

export const BAY_X0 = 62
export const BAY_PITCH = 30
export const CHASSIS_W = 24
export const CHASSIS_D = 32
export const CHASSIS_Y = -112
export const CHASSIS_H = 15

export const DRAWER_W = 22
export const DRAWER_D = 18
export const DRAWER_Y = -68
export const DRAWER_H = 8

export const JACK: Plan = { x: 6, y: -156, w: 24, d: 20, r: 2 }
export const JACK_H = 9

export const PLUG_Y = -146
export const PLUG_IN = 4
export const PLUG_R = 4.2

export const PUCK_X = -4
export const PUCK_Y = -114
export const PUCK_R = 6.4
export const PUCK_H = 7

export const GATE: Plan = { x: 242, y: -158, w: 30, d: 36, r: 2 }
export const GATE_H = 16

export const SPOOL = { x: 16, y: 18, r: 7.2 }
export const LABEL: Plan = { x: 196, y: 10, w: 46, d: 18, r: 1.5 }
export const RULER: Plan = { x: 76, y: 24, w: 108, d: 7, r: 1 }

export function bayCenter(index: number) {
  return BAY_X0 + index * BAY_PITCH
}

export function chassisPlan(index: number): Plan {
  return {
    x: bayCenter(index) - CHASSIS_W / 2,
    y: CHASSIS_Y,
    w: CHASSIS_W,
    d: CHASSIS_D,
    r: 2,
  }
}

export function drawerPlan(index: number): Plan {
  return {
    x: bayCenter(index) - DRAWER_W / 2,
    y: DRAWER_Y,
    w: DRAWER_W,
    d: DRAWER_D,
    r: 1.6,
  }
}

const cloud = (): Point3[] => [
  ...boxCorners(BASE, BASE_Z - 8, 36),
  ...boxCorners(GATE, 0, GATE_H + 4),
  [SPOOL.x, SPOOL.y, 18],
  [PLUG_IN - 16, PLUG_Y, 18],
  [PUCK_X, PUCK_Y, 14],
]

export const P: Projection = fitProjection(cloud(), WIDTH, HEIGHT, {
  pad: 32,
  azimuth: AZIMUTH,
  elevation: ELEVATION,
})
