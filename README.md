Arquitectura de la Solucion.

Se define una arquitectura escalable y con alta disponibilidad, se toma la decisión de utilizar Kubernetes ya que validando la compañía y al tener 13.000 clientes y esperando tener un crecimiento exponencial a futuro se sugiere la utilización de los kubernetes esto nos ayuda a la operación de plataformas robusta, optimizar costos con el afinamiento de los pod, dependiendo del consumo se puede llegar a tener negociaciones y compromisos de recursos reservados.

De igual manera se puede pensar en tener una infraestructura portable y tener su posibilidad de realizar migraciones a otras nubes sin mayor traumatismo.
La alta disponibilidad se define ya que al ser una entidad financiera y en colombia las regulación de la superfinanciera indica que las entidades deben tener una alta disponibilidad en otra región donde garantice la continuidad del negocio y la disponibilidad a sus usuarios.

Tener una solución de alta disponibilidad puede llegar a ser costoso por ello se debe entrar a plantear una solución donde se identifique los recursos cor de negocio y que podamos tener una disponibilidad de bajo costos, con recurso apagados o utilizara terraform que nos permite tener una Iaac para desplegar en otra región o en otra nube de tener una disponibilidad y no tener dependencia de la nube, todo esto se puede automatizar desde Github.

VPC y Subredes: Se crean subredes personalizadas en distintas zonas de disponibilidad.
Grupo de Seguridad: Restringe acceso solo a HTTPS y permite parametrizar direcciones IP permitidas.


![Arquitectura Prueba (1)](https://github.com/user-attachments/assets/18df7121-0aa3-46d0-89b0-f36549c17ec7)

Se crea el Terraform utilizando el servicio de ECS como lo indica el ejercicio, como lo defino en la arquitectura propongo EKS esto depende de tener claro el tamaño de la aplicación y el consumo que se tenga actualmente, si es una plataforma pequeña ECS es una solución confiable económica y no requiere mayor complejidad.



Justificación:

Enfoque declarativo y estado mantenido.

Compatibilidad con múltiples proveedores de nube.

Modularidad y reutilización de código.

Gran comunidad y documentación extensa.

Estructura del Proyecto:

my-terraform-project/
│── modules/                   # Módulos reutilizables para cada componente
│   ├── vpc/                   # Definición de VPC y subredes
│   ├── ecs/                   # Configuración del clúster ECS
│   ├── services/              # Definición de servicios ECS
│   ├── load_balancer/         # Configuración del ALB
│── environments/              # Configuraciones para dev, stg, prod
│── main.tf                    # Configuración principal de Terraform
│── variables.tf                # Definición de variables
│── outputs.tf                  # Valores de salida
│── terraform.tfvars            # Valores de las variables
│── README.md                   # Documentación del proyecto



## **Paso 1: Configurar el Entorno**

Antes de empezar, asegúrate de tener instalado:

- **AWS CLI** → [Descargar AWS CLI](https://aws.amazon.com/cli/)
- **Terraform** → Descargar Terraform
- **Docker** (para construir imágenes de contenedores)
- **GitHub CLI** (para gestionar secretos)

Autentica AWS en la CLI:

```bash
bash
CopiarEditar
aws configure

```

---

## **Paso 2: Crear la Infraestructura con Terraform**

Vamos a definir los recursos en Terraform:

✅ **VPC con subredes**

✅ **Clúster ECS**

✅ **Servicio Fargate con ALB**

✅ **Reglas de seguridad**

### **2.1. Inicializar el Proyecto Terraform**

```bash
bash
CopiarEditar
mkdir fargate-terraform && cd fargate-terraform
touch main.tf variables.tf outputs.tf

```

---

### **2.2. Definir Variables (variables.tf)**

```hcl
variable "aws_region" {
  default = "us-east-1"
}

variable "cluster_name" {
  default = "finaktiva-fargate-cluster"
}

variable "container_port" {
  default = 80
}

variable "task_cpu" {
  default = 256
}

variable "task_memory" {
  default = 512
}


```

---

### **2.3. Definir Infraestructura (main.tf)**

```hcl
provider "aws" {
  region = var.aws_region
}

# VPC y Subredes
resource "aws_vpc" "finaktiva_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "finaktiva_public_subnet" {
  vpc_id                  = aws_vpc.finaktiva_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Cluster ECS
resource "aws_ecs_cluster" "finaktiva_ecs_cluster" {
  name = var.cluster_name
}

# Definir el rol de ejecución de tareas
resource "aws_iam_role" "finaktiva_ecs_task_execution_role" {
  name = "finaktivaEcsTaskExecutionRole"
  
  assume_role_policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# Definir la tarea ECS
resource "aws_ecs_task_definition" "finaktiva_ecs_task" {
  family                   = "finaktiva-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.finaktiva_ecs_task_execution_role.arn
  cpu                      = var.task_cpu
  memory                   = var.task_memory

  container_definitions = jsonencode([
    {
      name      = "finaktiva-container"
      image     = "nginx"  # Cambiar por la imagen de tu aplicación
      cpu       = var.task_cpu
      memory    = var.task_memory
      essential = true
      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
      }]
    }
  ])
}

# Servicio ECS con Fargate
resource "aws_ecs_service" "finaktiva_ecs_service" {
  name            = "finaktiva-service"
  cluster         = aws_ecs_cluster.finaktiva_ecs_cluster.id
  task_definition = aws_ecs_task_definition.finaktiva_ecs_task.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.finaktiva_public_subnet.id]
    assign_public_ip = true
  }
}

#### Balanceador de Carga ###

# Crear Load Balancer
resource "aws_lb" "finaktiva_alb" {
  name               = "finaktiva-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.finaktiva_lb_sg.id]
  subnets           = [aws_subnet.finaktiva_public_subnet.id]
}

# Crear un Target Group
resource "aws_lb_target_group" "finaktiva_tg" {
  name     = "finaktiva-ecs-tg"
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.finaktiva_vpc.id
  target_type = "ip"
}

# Crear Listener en el LB
resource "aws_lb_listener" "finaktiva_alb_listener" {
  load_balancer_arn = aws_lb.finaktiva_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.finaktiva_tg.arn
  }
}

# Seguridad para el ALB
resource "aws_security_group" "finaktiva_lb_sg" {
  name   = "finaktiva-lb-security-group"
  vpc_id = aws_vpc.finaktiva_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


```

---

### **2.4. Crear el Balanceador de Carga (ALB)**

Agrega esto en `main.tf`:

```hcl


```

---

## **Paso 3: Aplicar la Infraestructura**

Ejecuta estos comandos para desplegar la infraestructura:

```bash
bash
CopiarEditar
terraform init      # Inicializar Terraform
terraform plan      # Verificar cambios
terraform apply -auto-approve  # Aplicar cambios

```

Obtén la URL del ALB:

```bash
bash
terraform output

```

---

## **Paso 4: Automatizar con GitHub Actions**

Crea el archivo `.github/workflows/deploy.yml`:

```yaml
CopiarEditar
name: Deploy to AWS Fargate with Terraform

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout código
      uses: actions/checkout@v3

    - name: Configurar AWS CLI
      uses: aws-actions/configure-aws-credentials@v1
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1

    - name: Instalar Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: 1.5.0

    - name: Inicializar Terraform
      run: terraform init

    - name: Aplicar Terraform
      run: terraform apply -auto-approve

```

**Importante:**

En GitHub, agrega las credenciales de AWS como **Secretos**:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

---

## **Paso 5: Pruebas y Monitoreo**

1. **Verifica el despliegue**
    
    bash
    terraform output
    
    ```
Validar la Infraestructura
Una vez desplegado, revisa la URL del servicio:

bash
aws ecs list-services --cluster my-fargate-cluster
Si configuraste un balanceador de carga, usa:

bash
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].DNSName'

    Copia la URL del balanceador de carga y accede desde un navegador.
    
2. **Habilitar Monitoreo en CloudWatch**
    
    ```hcl
    hcl
    CopiarEditar
    resource "aws_cloudwatch_metric_alarm" "high_cpu" {
      alarm_name          = "HighCPU"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "CPUUtilization"
      namespace           = "AWS/ECS"
      period              = 60
      statistic           = "Average"
      threshold           = 80
      alarm_description   = "CPU usage too high"
    }
    
    ```
 CI/CD
Herramienta: GitHub Actions
Justificación:
Integración nativa con GitHub.
Facilidad de configuración y uso.
Gran comunidad y documentación.
Pipeline
Crear un workflow de GitHub Actions.
Definir jobs para cada ambiente (dev, stg, prod).
Configurar Terraform en el pipeline:
terraform fmt para formateo del código.
terraform init para inicializar el backend.
terraform validate para verificar sintaxis.
terraform plan para visualizar cambios.
terraform apply para aplicar cambios en producción.
Implementar estrategias de despliegue:
Blue/Green
Rolling Update
Prueba Teórica o de Conocimientos Técnicos

Pregunta 1: Publicar un servidor en LAN con HTTPS
Opción 1: Configurar un Proxy Reverso con Nginx
-Configurar Nginx en un servidor con IP pública.
-Redirigir / al puerto 8080 y /servicio al puerto 8443 en la LAN.

Opción 2: AWS Application Load Balancer con reglas de reescritura
-Desplegar un ALB con reglas para enrutar tráfico al backend interno.
-Configurar un túnel VPN o AWS PrivateLink para comunicación con el servidor local.

Pregunta 2: Cliente no puede acceder a los servicios
-DNS incorrecto o no propagado.
-Bloqueo de firewall en el cliente.
-Problemas con el certificado SSL.
-Reglas de seguridad en AWS mal configuradas.
-Proxy o restricciones en la red del cliente.

Pregunta 3: Algoritmos de balanceo
-Round Robin: Distribuye tráfico equitativamente. Bueno para cargas balanceadas, este lo utilizaría para equilibrar las peticiones que se realicen y logran una mayor eficiencia y respuesta.
-Weighted Round Robin: Prioriza ciertos servidores con más capacidad. Esta opción la utiliza para redimir tráfico a pod con ciertas capacidades y optimizados tomando como prioridad la necesidad del negocio.
-Least Connection: Envía tráfico al servidor con menos conexiones activas, Esta opción se puede utilizar para realizar un balanceo de carga y que la peticiones siempre se equilibre tomando como referencia la disponibilidad de la infra.
-Source Hash: Mantiene afinidad del usuario según IP. Esta opción  la utilizan para una solución que requiere trabajar políticas de seguridad y acceso a ciertos servicios validando su origen.
-URI Hash: Balancea tráfico según la URL solicitada. Ideal para caché distribuido. Esta opción la utilizaria para priorizar API que requieren una alta disponibilidad y para la entrega de contenido rápido con el objetivo de agilizar la entrega de información al usuario sin importar su ubicación.
   
Agunos errores que se presentaron durante la preparacion de la prueba.

errores.

hint: Using 'master' as the name for the initial branch. This default branch name
hint: is subject to change. To configure the initial branch name to use in all
hint: of your new repositories, which will suppress this warning, call:
hint:
hint:   git config --global init.defaultBranch <name>
hint:
hint: Names commonly chosen instead of 'master' are 'main', 'trunk' and
hint: 'development'. The just-created branch can be renamed via this command:
hint:
hint:   git branch -m <name>

Este error se presento porque solo tenia una rama creada. para solucionarlo y la buena practica es no trabajar con la master sino tener una rama de main, y otras para los diferentes ambientes.


