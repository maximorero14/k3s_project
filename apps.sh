#!/bin/bash

apply_and_wait() {
    local file=$1
    local output
    
    echo "Aplicando $file..."
    output=$(kubectl apply -f "$file" --wait=true 2>&1)
    
    # Si la salida contiene "unchanged", no hay cambios
    if echo "$output" | grep -q "unchanged"; then
        echo "Sin cambios en $file"
    else
        echo "Cambios aplicados en $file, esperando 10 segundos..."
        sleep 20
    fi
}

apply_and_wait "monitoring/tempo/tempo.yaml"
apply_and_wait "monitoring/opentelemetry/opentelemetry.yaml"
apply_and_wait "monitoring/prometheus-k3s/prometheus-app.yaml"
apply_and_wait "monitoring/loki/loki.yaml"
apply_and_wait "monitoring/grafana/grafana-app.yaml"
apply_and_wait "postgres/postgres.yaml"
apply_and_wait "queue/kafka.yaml"
apply_and_wait "auth/argocd/application.yaml"
apply_and_wait "payment/argocd/application.yaml"
