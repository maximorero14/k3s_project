#!/bin/bash

# 1. Parar K3s
sudo systemctl stop k3s

# 2. Usar script oficial
sudo /usr/local/bin/k3s-uninstall.sh

# 3. Esperar un momento
sleep 10

# 4. Reinstalar
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.30.1+k3s1" sh -

# Copiar la configuración de K3s a kubectl
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# O usar la variable de entorno
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Esperar a que K3s esté completamente listo
echo "Esperando a que K3s esté listo..."

# Esperar a que el servicio esté activo
while ! systemctl is-active --quiet k3s; do
    echo "Esperando a que el servicio K3s se active..."
    sleep 5
done

# Esperar a que el nodo esté Ready
while ! kubectl get nodes | grep -q " Ready "; do
    echo "Esperando a que el nodo esté Ready..."
    sleep 5
done

# Esperar a que los pods del sistema estén ejecutándose
echo "Esperando a que los pods del sistema estén listos..."
kubectl wait --for=condition=Ready pods --all -n kube-system --timeout=300s

# Verificación final
echo "Estado final del cluster:"
kubectl get nodes
kubectl get pods -A

echo "¡K3s está completamente listo!"