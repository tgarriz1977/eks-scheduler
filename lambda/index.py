import boto3
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

eks_client = boto3.client("eks")
sns_client = boto3.client("sns")

SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")


def handler(event, context):
    """
    Escala los node groups de un cluster EKS.

    Event esperado:
    {
        "cluster_name": "mi-cluster",
        "action": "stop" | "start",
        "node_groups": {
            "ng-general": {"min_size": 2, "desired_size": 3, "max_size": 5}
        }
    }

    - "stop": escala todos los node groups a 0.
    - "start": restaura los node groups a los valores definidos en "node_groups".

    Si "node_groups" no se especifica en "start", usa min=2, desired=2, max=4 por defecto.
    """
    cluster_name = event["cluster_name"]
    action = event["action"]
    node_groups_config = event.get("node_groups", {})

    logger.info(f"Action: {action} | Cluster: {cluster_name}")

    # Obtener todos los node groups del cluster
    nodegroups = eks_client.list_nodegroups(clusterName=cluster_name)["nodegroups"]
    logger.info(f"Node groups encontrados: {nodegroups}")

    results = []

    for ng_name in nodegroups:
        if action == "stop":
            scaling = {"minSize": 0, "desiredSize": 0}
        elif action == "start":
            # Usar config especifica si existe, sino valores por defecto
            ng_config = node_groups_config.get(ng_name, {})
            scaling = {
                "minSize": ng_config.get("min_size", 2),
                "desiredSize": ng_config.get("desired_size", 2),
                "maxSize": ng_config.get("max_size", 4),
            }
        else:
            raise ValueError(f"Accion no valida: {action}. Usar 'stop' o 'start'.")

        logger.info(f"Actualizando {ng_name}: {scaling}")

        try:
            eks_client.update_nodegroup_config(
                clusterName=cluster_name,
                nodegroupName=ng_name,
                scalingConfig=scaling,
            )
            results.append({"nodegroup": ng_name, "status": "ok", "scaling": scaling})
        except Exception as e:
            logger.error(f"Error actualizando {ng_name}: {str(e)}")
            results.append({"nodegroup": ng_name, "status": "error", "error": str(e)})

    response = {
        "cluster": cluster_name,
        "action": action,
        "results": results,
    }
    logger.info(f"Resultado: {json.dumps(response)}")

    # Notificar por email via SNS
    if SNS_TOPIC_ARN:
        action_label = "APAGADO" if action == "stop" else "ENCENDIDO"
        has_errors = any(r["status"] == "error" for r in results)
        status_label = "con ERRORES" if has_errors else "exitoso"

        subject = f"EKS Scheduler: {action_label} {status_label} - {cluster_name}"

        details = []
        for r in results:
            if r["status"] == "ok":
                details.append(f"  - {r['nodegroup']}: OK -> {r['scaling']}")
            else:
                details.append(f"  - {r['nodegroup']}: ERROR -> {r['error']}")

        message = (
            f"Cluster: {cluster_name}\n"
            f"Accion: {action_label}\n"
            f"Estado: {status_label}\n\n"
            f"Detalle por node group:\n" + "\n".join(details)
        )

        try:
            sns_client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject=subject[:100],
                Message=message,
            )
            logger.info("Notificacion enviada por SNS")
        except Exception as e:
            logger.error(f"Error enviando notificacion SNS: {str(e)}")

    return response
