# @donalabs/landing

Landing estática bilingüe (`/en`, `/es`). Next.js 16.

```bash
pnpm --filter @donalabs/landing dev     # http://localhost:3000
pnpm --filter @donalabs/landing build
```

## `NEXT_PUBLIC_SITE_URL` (obligatoria en deploy)

Origen público de la web, sin barra final (p. ej. `https://<tu-dominio>`). Se usa como `metadataBase` para las URLs absolutas de `canonical` y `hreflang` (`en`, `es`, `x-default`).

- Se fija **en el entorno del build** del deploy (Next la incrusta al compilar); cambiarla exige recompilar.
- No hay dominio en el código. Si falta, se usa `http://localhost:3000`, **solo para desarrollo**: un build de producción sin la variable publicaría enlaces canónicos a localhost.
- Plantilla: `.env.example` (cópiala a `.env.local` en local si la necesitas).
