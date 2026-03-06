variable "aws_region" {
  description = "Region de AWS"
  type        = string
  default     = "us-east-2"
}

variable "cluster_name" {
  description = "Nombre del cluster EKS"
  type        = string
  default     = "colegio-staging"
}

variable "schedule_stop" {
  description = "Cron para apagar los nodos (UTC). Default: 22:00 ART = 01:00 UTC"
  type        = string
  default     = "cron(0 1 * * ? *)"
}

variable "schedule_start" {
  description = "Cron para encender los nodos (UTC). Default: 07:00 ART = 10:00 UTC"
  type        = string
  default     = "cron(0 10 * * ? *)"
}

variable "node_groups_config" {
  description = "Configuracion de scaling para cada node group al encender. Si no se especifica, usa min=2, desired=2, max=4"
  type = map(object({
    min_size     = number
    desired_size = number
    max_size     = number
  }))
  default = {
    "gpu-spot" = {
      min_size     = 0
      desired_size = 0
      max_size     = 1
    }
    "green-20250110034945861700000001" = {
      min_size     = 2
      desired_size = 2
      max_size     = 3
    }
  }
}

variable "schedule_timezone" {
  description = "Timezone para los schedules de EventBridge"
  type        = string
  default     = "America/Argentina/Buenos_Aires"
}

variable "notification_email" {
  description = "Email para recibir notificaciones de encendido/apagado"
  type        = string
  default     = "tgarriz@gmail.com"
}

variable "tags" {
  description = "Tags comunes para los recursos"
  type        = map(string)
  default = {
    Project   = "eks-scheduler"
    ManagedBy = "terraform"
  }
}
