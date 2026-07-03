# ==============================================================================
# 1. ECS CONTAINER ORCHESTRATION CLUSTER
# ==============================================================================
resource "aws_ecs_cluster" "this" {
  name = "${var.environment}-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ==============================================================================
# 2. HIGH-AVAILABILITY APPLICATION LOAD BALANCER (ALB)
# ==============================================================================
resource "aws_lb" "external" {
  name               = "${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = {
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "app" {
  name        = "${var.environment}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for ECS Fargate 'awsvpc' network mode

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.external.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ==============================================================================
# 3. ECS FARGATE TASK DEFINITION (APPLICATION BLUEPRINT)
# ==============================================================================
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.environment}-task"
  network_mode             = "awsvpc" # Injects containers directly into VPC subnets
  requires_compatibilities = ["FARGATE"]
  cpu                      = "2"
  memory                   = "4"
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([
    {
      name      = "web-app"
      image     = "907739325292.dkr.ecr.us-east-1.amazonaws.com/nginxdemos-hello:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

# ==============================================================================
# 4. ECS FARGATE SERVICE (LIFECYCLE ENFORCEMENT & TRAFFIC PROVISIONING)
# ==============================================================================
resource "aws_ecs_service" "app" {
  name            = "${var.environment}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false # Keeps containers completely unreachable from the public internet
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "web-app"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]
}

# ==============================================================================
# 5. ZERO-TRUST FIREWALL ACCESS CONTROLS (SECURITY GROUPS)
# ==============================================================================
resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = "Allows inbound public HTTP traffic to the Load Balancer front door"
  vpc_id      = var.vpc_id

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

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.environment}-ecs-tasks-sg"
  description = "Isolates container tasks, forcing all traffic exclusively through the ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id] # Source Chaining: Blocks raw internet access
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==============================================================================
# 6. IAM ROLE DELEGATION (SECURE AWS SERVICE ASSUMPTION)
# ==============================================================================
resource "aws_iam_role" "ecs_execution" {
  name = "${var.environment}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

