import type { ReactNode } from "react"

import { Plate } from "../iso/react/draw"
import "../iso/iso.css"
import { readoutOf } from "./model"
import { HEIGHT, WIDTH } from "./view"
import "./bench.css"

export function BenchPlate({
  children,
  interactive = false,
}: {
  children: ReactNode
  interactive?: boolean
}) {
  return (
    <div className="iso bench-iso" data-theme="light">
      <Plate
        fig="Fig 1"
        title="El borde común"
        hint="Pulsa un aparato"
        readout={readoutOf("Vaultwarden")}
        keys={[
          { mark: "lit", label: "El pulso, solo en el borde" },
          { mark: "raised", label: "El embarrado compartido" },
          { mark: "edge", label: "El cable del otro proyecto" },
          { mark: "dim", label: "El cajón, sin salida" },
        ]}
        caption="Seis aparatos comparten el embarrado de atrás: esa es la red común. La clavija de la izquierda es otro proyecto; el pulso recorre el cobre hasta el aparato que eliges y se queda ahí. El cajón de cada uno no tiene cable. La falleba de la derecha sigue echada. El carrete suelto, delante, es la utilidad de medios: está en la mesa y no se enchufa."
      >
        <svg
          className="iso-svg"
          viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
          role={interactive ? "group" : "img"}
          aria-label="Banco de seis aparatos unidos por un embarrado. Los cajones de delante no tienen cable."
        >
          {children}
        </svg>
      </Plate>
    </div>
  )
}
