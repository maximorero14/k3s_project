#!/bin/bash

# Script para instalar Argo CD en Ubuntu Server
# Autor: Script generado para instalación de Argo CD
# Fecha: $(date)

set -e  # Salir si algún comando falla

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
NEW_PASSWORD="River.1991"
ADMIN_USER="admin"

# Función para imprimir mensajes con colores
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar si el script se ejecuta como root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "No ejecutes este script como root. Usa un usuario con permisos sudo."
        exit 1
    fi
}

# Verificar si kubectl está instalado
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl no está instalado. Por favor instala kubectl primero."
        print_status "Puedes instalarlo con: sudo snap install kubectl --classic"
        exit 1
    fi
    print_success "kubectl encontrado"
}

# Verificar conexión a cluster de Kubernetes
check_k8s_connection() {
    print_status "Verificando conexión al cluster de Kubernetes..."
    if ! kubectl cluster-info &> /dev/null; then
        print_error "No se puede conectar al cluster de Kubernetes"
        print_status "Asegúrate de tener configurado kubectl correctamente"
        exit 1
    fi
    print_success "Conexión al cluster de Kubernetes verificada"
}

# Crear namespace para Argo CD
create_namespace() {
    print_status "Creando namespace argocd..."
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    print_success "Namespace argocd creado/verificado"
}

# Instalar Argo CD
install_argocd() {
    print_status "Instalando Argo CD..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    print_success "Argo CD instalado"
}

# Configurar servicio como NodePort
configure_nodeport() {
    print_status "Configurando servicio argocd-server como NodePort..."
    
    # Patchear el servicio para convertirlo en NodePort
    kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort","ports":[{"port":443,"targetPort":8080,"nodePort":31427}]}}'
    
    print_success "Servicio configurado como NodePort en puerto 31427"
}

# Esperar a que los pods estén listos
wait_for_pods() {
    print_status "Esperando a que los pods de Argo CD estén listos..."
    
    # Verificar qué deployments existen primero
    print_status "Verificando deployments disponibles..."
    kubectl get deployments -n argocd
    
    # Esperar por los deployments principales
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-dex-server -n argocd
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-redis -n argocd
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
    
    # Verificar si existe argocd-applicationset-controller
    if kubectl get deployment argocd-applicationset-controller -n argocd &> /dev/null; then
        kubectl wait --for=condition=available --timeout=300s deployment/argocd-applicationset-controller -n argocd
    fi
    
    # Verificar si existe argocd-notifications-controller
    if kubectl get deployment argocd-notifications-controller -n argocd &> /dev/null; then
        kubectl wait --for=condition=available --timeout=300s deployment/argocd-notifications-controller -n argocd
    fi
    
    print_success "Todos los pods de Argo CD están listos"
}

# Instalar Argo CD CLI
install_argocd_cli() {
    print_status "Instalando Argo CD CLI..."
    
    # Obtener la última versión
    VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep tag_name | cut -d '"' -f 4)
    
    # Descargar el binario
    curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
    
    # Hacer ejecutable y mover a /usr/local/bin
    chmod +x argocd
    sudo mv argocd /usr/local/bin/
    
    print_success "Argo CD CLI instalado. Versión: $VERSION"
}

# Obtener contraseña inicial y cambiarla
change_admin_password() {
    print_status "Obteniendo contraseña inicial del admin..."
    INITIAL_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    print_success "Contraseña inicial obtenida"
    
    # Esperar un poco más para asegurar que el servicio esté completamente listo
    print_status "Esperando a que el servicio esté completamente listo..."
    sleep 30
    
    # Obtener la IP del nodo
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    print_status "Cambiando contraseña del admin..."
    
    # Intentar login con la contraseña inicial
    if argocd login $NODE_IP:31427 --username $ADMIN_USER --password "$INITIAL_PASSWORD" --insecure; then
        # Cambiar la contraseña
        argocd account update-password --account $ADMIN_USER --current-password "$INITIAL_PASSWORD" --new-password "$NEW_PASSWORD"
        print_success "Contraseña cambiada exitosamente"
        
        # Hacer login con la nueva contraseña
        argocd login $NODE_IP:31427 --username $ADMIN_USER --password "$NEW_PASSWORD" --insecure
        print_success "Login realizado con nueva contraseña"
    else
        print_warning "No se pudo hacer login automático. Podrás cambiar la contraseña manualmente desde la UI."
    fi
}

# Mostrar información de acceso
show_access_info() {
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    echo ""
    print_success "¡Instalación de Argo CD completada!"
    echo ""
    echo "=== INFORMACIÓN DE ACCESO ==="
    echo "• URL Web: https://$NODE_IP:31427"
    echo "• Usuario: $ADMIN_USER"
    echo "• Contraseña: $NEW_PASSWORD"
    echo "• Namespace: argocd"
    echo ""
    echo "=== COMANDOS ÚTILES ==="
    echo "• Ver pods: kubectl get pods -n argocd"
    echo "• Ver servicios: kubectl get svc -n argocd"
    echo "• Login CLI: argocd login $NODE_IP:31427 --username $ADMIN_USER --password $NEW_PASSWORD --insecure"
    echo ""
    echo "=== PRÓXIMOS PASOS ==="
    echo "1. Accede a la UI web en: https://$NODE_IP:31427"
    echo "2. Configura tus repositorios Git"
    echo "3. Crea tus primeras aplicaciones"
    echo ""
    echo "Nota: Acepta el certificado autofirmado en tu navegador"
}

# Función principal
main() {
    print_status "Iniciando instalación de Argo CD en Ubuntu Server"
    echo ""
    
    check_root
    check_kubectl
    check_k8s_connection
    create_namespace
    install_argocd
    wait_for_pods
    configure_nodeport
    install_argocd_cli
    change_admin_password
    show_access_info
}

# Ejecutar función principal
main "$@"