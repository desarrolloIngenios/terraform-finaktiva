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
