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
CopiarEditar
terraform output

```

---

## **Paso 4: Automatizar con GitHub Actions**

Crea el archivo `.github/workflows/deploy.yml`:

```yaml
yaml
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
    
    ```bash
    bash
    CopiarEditar
    terraform output
    
    ```
    
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
    

Herrores.

hint: Using 'master' as the name for the initial branch. This defa
