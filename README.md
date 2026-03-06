# EKS Scheduler

Apaga y enciende automáticamente los nodos de un cluster EKS según horarios programados, para reducir costos fuera del horario laboral.

- **Apagado**: 22:00 ART — escala todos los node groups a 0
- **Encendido**: 07:00 ART — restaura los node groups a sus valores configurados

---

## Prerequisitos

- Terraform >= 1.0
- AWS CLI configurado con credenciales que tengan permisos sobre EKS, Lambda, IAM, EventBridge Scheduler y SNS
- Acceso al cluster EKS target

---

## Deploy con Terraform

### 1. Crear el archivo de variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Editar `terraform.tfvars` con los valores del entorno:

```hcl
aws_region   = "us-east-2"
cluster_name = "nombre-del-cluster"

# Scaling de cada node group al encender.
# La clave debe ser el nombre exacto del node group en AWS.
# Si un node group no aparece acá, al encender usará min=2, desired=2, max=4.
node_groups_config = {
  "ng-general" = {
    min_size     = 2
    desired_size = 3
    max_size     = 5
  }
}

# Dejar vacío para deshabilitar notificaciones por email
notification_email = "equipo@empresa.com"
```

### 2. Aplicar

```bash
terraform init
terraform plan
terraform apply
```

Terraform empaqueta automáticamente `lambda/index.py` en un zip al momento del apply. No hay build manual.

### 3. Confirmar suscripción SNS (si se configuró email)

Al terminar el apply, AWS envía un email de confirmación a la dirección configurada. **Hacer clic en "Confirm subscription"** antes de que llegue la primera notificación, de lo contrario los emails no se entregarán.

### Destruir los recursos

```bash
terraform destroy
```

---

## Levantar los workers manualmente

En caso de necesidad (falla del scheduler, intervención urgente fuera de horario, etc.), se puede invocar la Lambda directamente desde la AWS CLI.

### Encender los nodos

```bash
aws lambda invoke \
  --function-name eks-scheduler \
  --cli-binary-format raw-in-base64-out \
  --payload '{
    "cluster_name": "nombre-del-cluster",
    "action": "start",
    "node_groups": {
      "ng-general": {"min_size": 2, "desired_size": 3, "max_size": 5}
    }
  }' \
  response.json && cat response.json
```

El campo `node_groups` es opcional. Si se omite, todos los node groups se levantan con `min=2, desired=2, max=4`. Si se incluye, solo los node groups listados usan esos valores; los demás usan los defaults.

### Apagar los nodos

> **Advertencia**: esto escala los nodos a 0 de inmediato. Los pods en ejecución serán terminados.

```bash
aws lambda invoke \
  --function-name eks-scheduler \
  --cli-binary-format raw-in-base64-out \
  --payload '{
    "cluster_name": "nombre-del-cluster",
    "action": "stop"
  }' \
  response.json && cat response.json
```

### Verificar el resultado

La respuesta en `response.json` lista el estado por node group:

```json
{
  "cluster": "nombre-del-cluster",
  "action": "start",
  "results": [
    {"nodegroup": "ng-general", "status": "ok", "scaling": {"minSize": 2, "desiredSize": 3, "maxSize": 5}}
  ]
}
```

Si algún node group tiene `"status": "error"`, el campo `"error"` contiene el mensaje de AWS. Los demás node groups no se ven afectados por el error de uno.

### Alternativa: escalar directamente con AWS CLI (sin Lambda)

Si la Lambda no está disponible, se puede escalar un node group directamente:

```bash
# Encender un node group específico
aws eks update-nodegroup-config \
  --cluster-name nombre-del-cluster \
  --nodegroup-name ng-general \
  --scaling-config minSize=2,desiredSize=3,maxSize=5

# Apagar un node group específico
aws eks update-nodegroup-config \
  --cluster-name nombre-del-cluster \
  --nodegroup-name ng-general \
  --scaling-config minSize=0,desiredSize=0,maxSize=5

# Ver el estado actual de los node groups
aws eks list-nodegroups --cluster-name nombre-del-cluster
aws eks describe-nodegroup --cluster-name nombre-del-cluster --nodegroup-name ng-general \
  --query 'nodegroup.scalingConfig'
```
