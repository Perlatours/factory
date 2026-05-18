# inputs/ — {{PROVIDER}}

Coloca aquí:
- Documentación bruta del provider (PDF, Postman collection, Swagger JSON, examples)
- `03-credentials.local.env` ← **git-ignored** con `PROVIDER_SANDBOX_USER`, `PROVIDER_SANDBOX_TOKEN`, etc.

Estructura sugerida:
```
inputs/
├── doc/
│   ├── swagger.json
│   ├── postman_collection.json
│   └── examples/
├── 03-credentials.local.env       # git-ignored
└── volume.md                       # nº hoteles · frecuencia · etc.
```
