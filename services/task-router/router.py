#!/usr/bin/env python3
"""PoC: ask a local Ollama model which agent should handle each task.

Stdlib only. Output: one JSON object per task, e.g.
{"id": "t1", "agent": "n8n", "confidence": 0.9, "reason": "..."}
"""
import argparse, json, os, sys, urllib.request

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11435")
MODEL = os.environ.get("ROUTER_MODEL", "qwen2.5:1.5b")


def build_messages(task, agents):
    roster = "\n".join(f"- {a['name']}: {a['description']}" for a in agents)
    system = ("Eres un enrutador de tareas. Elige exactamente UN agente de la lista "
              "para la tarea. Responde solo JSON con agent, confidence (0-1) y reason (breve).\n"
              f"Agentes:\n{roster}")
    return [{"role": "system", "content": system}, {"role": "user", "content": task}]


def schema(agents):
    return {
        "type": "object",
        "properties": {
            "agent": {"type": "string", "enum": [a["name"] for a in agents]},
            "confidence": {"type": "number"},
            "reason": {"type": "string"},
        },
        "required": ["agent", "confidence", "reason"],
    }


def route(task, agents, url=OLLAMA_URL, model=MODEL, timeout=120):
    body = {"model": model, "messages": build_messages(task, agents), "stream": False,
            "format": schema(agents), "options": {"temperature": 0}}
    req = urllib.request.Request(f"{url}/api/chat", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        content = json.load(r)["message"]["content"]
    decision = json.loads(content)
    names = {a["name"] for a in agents}
    if decision.get("agent") not in names:  # never trust the model blindly
        decision = {"agent": None, "confidence": 0.0, "reason": f"invalid answer: {content[:200]}"}
    return decision


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--agents", default=os.path.join(os.path.dirname(__file__) or ".", "agents.json"))
    ap.add_argument("--tasks", help="JSON file: [{id, task}]")
    ap.add_argument("--task", help="single task text")
    ap.add_argument("--dry-run", action="store_true", help="print the request, do not call Ollama")
    a = ap.parse_args()
    agents = json.load(open(a.agents, encoding="utf-8"))
    if a.task:
        tasks = [{"id": "cli", "task": a.task}]
    elif a.tasks:
        tasks = json.load(open(a.tasks, encoding="utf-8"))
    else:
        ap.error("use --task or --tasks")
    for t in tasks:
        if a.dry_run:
            print(json.dumps({"id": t["id"], "model": MODEL, "messages": build_messages(t["task"], agents),
                              "format": schema(agents)}, ensure_ascii=False))
            continue
        try:
            d = route(t["task"], agents)
        except Exception as e:  # network/model errors are reported, not fatal
            d = {"agent": None, "confidence": 0.0, "reason": f"error: {e}"}
        print(json.dumps({"id": t["id"], **d}, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    sys.exit(main())
