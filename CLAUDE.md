# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# EKS Scheduler

Automatización para apagar y encender los nodos de un cluster EKS en horarios programados, para ahorro de costos.

## Horarios

- **Apagado**: 22:00 ART (01:00 UTC) - escala node groups a 0
- **Encendido**: 07:00 ART (10:00 UTC) - restaura node groups a valores configurados
- Argentina no tiene DST, timezone es siempre UTC-3

## Comandos

```bash
# Deploy
cd terraform && terraform init && terraform plan && terraform apply

# Test manual (CUIDADO: stop apaga los nodos inmediatamente)
aws lambda invoke --function-name eks-scheduler \
  --payload '{"cluster_name":"CLUSTER","action":"stop"}' response.json

aws lambda invoke --function-name eks-scheduler \
  --payload '{"cluster_name":"CLUSTER","action":"start"}' response.json
```

## Arquitectura

**Flujo**: EventBridge Scheduler → Lambda (`lambda/index.py`) → EKS API + SNS

**Lambda** (`python3.12`, timeout 60s):
- Descubre node groups dinámicamente con `list_nodegroups` (no hardcodeados)
- `stop`: escala todos a `minSize=0, desiredSize=0` (no toca `maxSize`)
- `start`: usa config de `node_groups` del evento; si un node group no tiene config, usa `min=2, desired=2, max=4` por defecto
- Notifica por SNS si `SNS_TOPIC_ARN` está presente en env vars

**Terraform packaging**: `lambda.tf` usa `archive_file` para zipear `lambda/index.py` automáticamente al hacer `terraform apply`. No hay build manual.

**SNS condicional**: si `notification_email = ""`, no se crean recursos SNS (`count = 0`), y `SNS_TOPIC_ARN` queda vacío en Lambda.

**EventBridge Scheduler** (no EventBridge Rules): soporta timezone nativa via `schedule_expression_timezone`, el cron se expresa en hora local ART.

## Configuración

Copiar `terraform/terraform.tfvars.example` a `terraform/terraform.tfvars` y ajustar:
- `cluster_name`: nombre del cluster EKS target
- `node_groups_config`: scaling por node group al encender. Clave = nombre exacto del node group en AWS
- `notification_email`: dejar vacío `""` para deshabilitar notificaciones

## Notificaciones

Después del primer deploy con email configurado, confirmar la suscripción SNS desde el email recibido de AWS antes de que llegue la primera notificación.
