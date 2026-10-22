# Task router (PoC, opcional)

Prueba de concepto: un modelo local de **Ollama 0.40.x** (imagen `ollama/ollama:0.40.8`) decide a qué agente (Dona, nova-context, Hermes, n8n) le toca cada tarea y devuelve JSON:

```json
{"id": "t1", "agent": "n8n", "confidence": 0.92, "reason": "flujo programado"}
```

La salida se valida contra un JSON schema (`format` de Ollama) con `enum` de agentes; si el modelo devuelve algo fuera de la lista, el agente queda en `null`. **No ejecuta nada**: solo decide.

## Ejecutar en local

No arranca con el stack normal; requiere el perfil `router`.

```bash
docker compose --profile router up -d router-ollama
# modelo pequeño (~1 GB). Elige otro con ROUTER_MODEL en .env
docker exec donalabs-router-ollama ollama pull qwen2.5:1.5b
docker compose --profile router run --rm task-router
# una tarea suelta:
docker compose --profile router run --rm task-router python router.py --task "Avisa por correo a los testers"
```

Sin Docker (Ollama local en el 11434): `OLLAMA_URL=http://localhost:11434 python3 router.py --tasks sample-tasks.json`.
Sin Ollama: `python3 router.py --tasks sample-tasks.json --dry-run` muestra la petición.

## Archivos
- `agents.json`: agentes y su descripción (lo que el modelo lee para decidir).
- `sample-tasks.json`: 5 tareas de ejemplo con el agente esperado implícito (t1/t5 n8n, t2 nova-context, t3 Hermes, t4 Dona).
- `router.py`: cliente stdlib de `/api/chat`.

## Variables
`ROUTER_OLLAMA_IMAGE_TAG` (0.40.8), `ROUTER_MODEL` (qwen2.5:1.5b), `ROUTER_OLLAMA_HOST_PORT` (11435, para no chocar con un Ollama del host).

## Siguiente paso
Medir aciertos sobre ~50 tareas reales y, si funciona, exponerlo como endpoint para n8n / el Tool Gateway.
