import type { Ref } from "react"

import { Dots, Line, Solid, Wire } from "../iso/react/draw"
import {
  baseScrews,
  baseSlab,
  bays,
  bead,
  busGroove,
  busPosts,
  busSlab,
  busStops,
  feed,
  feet,
  gateBolt,
  gateHasp,
  gateHead,
  gateKey,
  gatePosts,
  gateScrews,
  groove,
  jackBore,
  jackSlab,
  jackScrews,
  labelRules,
  labelSlab,
  labelScrews,
  leadOf,
  plugGrip,
  plugKnurl,
  plugNeck,
  puck,
  puckCap,
  rulerSlab,
  rulerTicks,
  spoolBarrel,
  spoolBore,
  spoolFlangeBottom,
  spoolFlangeTop,
} from "./geometry"

const lead = leadOf()

export function BenchScene({
  beadRef,
}: {
  beadRef?: Ref<SVGGElement>
}) {
  return (
    <g>
      {feet.map((foot) => (
        <g key={foot.key}>
          <Solid paths={foot.flange} tone="lo" />
          <Solid paths={foot.foot} tone="mid" />
        </g>
      ))}

      <Solid paths={baseSlab} tone="mid" halo>
        <Line d={groove} tone="faint" />
        <Line d={baseScrews.rings} tone="lo" />
      </Solid>
      <Dots points={baseScrews.dots} size={0.48} tone="mid" />

      {busPosts.map((post) => (
        <g key={post.key}>
          <Solid paths={post.collar} tone="lo" />
          <Solid paths={post.post} tone="mid" crease="none" />
        </g>
      ))}

      <Solid paths={jackSlab} tone="mid">
        <Line d={jackBore} tone="lo" />
        <Line d={jackScrews.rings} tone="lo" />
      </Solid>
      <Dots points={jackScrews.dots} size={0.42} tone="mid" />

      {gatePosts.map((post, index) => (
        <Solid key={`gate-post-${index}`} paths={post} tone="mid" />
      ))}
      <Solid paths={gateHead} tone="mid" />
      <Solid paths={gateBolt} tone="lo" />
      <Solid paths={gateHasp} tone="lo" flat>
        <Line d={gateKey} tone="mid" />
        <Line d={gateScrews.rings} tone="faint" />
      </Solid>
      <Dots points={gateScrews.dots} size={0.38} tone="mid" />

      {bays.map((bay) => (
        <g key={`drawer-${bay.index}`} data-bay={bay.index}>
          <Solid paths={bay.drawer} tone="lo">
            <Line d={bay.seal} tone="faint" />
          </Solid>
          <Solid paths={bay.pull} tone="mid" />
        </g>
      ))}

      {bays.map((bay) => (
        <g key={`chassis-${bay.index}`} data-bay={bay.index}>
          <Solid paths={bay.chassis} tone="mid" inner={<Line d={bay.seam} tone="faint" />}>
            {bay.vents.map((vent) => (
              <Line key={vent} d={vent} tone="lo" />
            ))}
            <Line d={bay.screws.rings} tone="lo" />
          </Solid>
          <Dots points={bay.screws.dots} size={0.4} tone="mid" />
          <Solid paths={bay.lamp} tone="mid" />
          <Solid paths={bay.lens} tone="hi">
            <Line d={bay.bezel} tone="lo" />
          </Solid>
          <Solid paths={bay.neck} tone="lo" />
          <Solid paths={bay.knob} tone="mid">
            <Line d={bay.knurl} tone="lo" />
          </Solid>
        </g>
      ))}

      {busStops.map((stop, index) => (
        <Solid key={`stop-${index}`} paths={stop} tone="lo" />
      ))}
      <Solid paths={busSlab} tone="hi">
        <Line d={busGroove} tone="faint" />
        {bays.map((bay) => (
          <Line key={`tick-${bay.index}`} d={bay.tick} tone="mid" />
        ))}
      </Solid>
      {bays.map((bay) => (
        <g key={`collar-${bay.index}`}>
          <Solid paths={bay.collar} tone="mid" />
        </g>
      ))}

      <Wire from={feed.from} to={feed.to} tone="mid" />
      {bays.map((bay) => (
        <g key={`jumper-${bay.index}`} data-jumper={bay.index} data-bay={bay.index}>
          <Wire
            from={bay.jumper.from}
            to={bay.jumper.to}
            tone={bay.index === 0 ? "lit" : "lo"}
          />
        </g>
      ))}

      <Solid paths={puck} tone="mid">
        <Line d={puckCap} tone="lo" />
      </Solid>
      <g>
        <Solid paths={plugGrip} tone="mid">
          <Line d={plugKnurl} tone="lo" />
        </Solid>
        <Solid paths={plugNeck} tone="lo" />
      </g>
      <Wire from={lead.from} to={lead.to} tone="mid" />

      <g ref={beadRef}>
        <Solid paths={bead} lit />
      </g>

      <Solid paths={spoolFlangeBottom} tone="lo" />
      <Solid paths={spoolBarrel} tone="mid" crease="none" />
      <Solid paths={spoolFlangeTop} tone="lo">
        <Line d={spoolBore} tone="mid" />
      </Solid>

      <Solid paths={labelSlab} tone="lo" flat>
        {labelRules.map((rule, index) => (
          <Line key={`rule-${index}`} d={rule} tone="lo" free />
        ))}
        <Line d={labelScrews.rings} tone="faint" />
      </Solid>
      <Dots points={labelScrews.dots} size={0.36} tone="mid" />

      <Solid paths={rulerSlab} tone="lo" flat>
        <Line d={rulerTicks.minor} tone="lo" />
        <Line d={rulerTicks.major} tone="mid" />
      </Solid>
    </g>
  )
}
