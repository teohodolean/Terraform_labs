provider "aws" {
  region = "us-west-2"
}


resource "aws_security_group" "allow_http_ssh_lb" {
  name        = "allow_http_ssh_lb"

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }



  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_http_ssh"
  }
}


resource "aws_lb" "load-balancer-labs" {
  name               = "load-balancer-labs"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_http_ssh_lb.id]
  subnets            = ["subnet-0048ff8647765d9e4","subnet-01633bd3e8d2842e9"]
}

resource "aws_lb_target_group" "target-lb" {
  name     = "target-lb"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-0e2aa8a01afce1ea3"
health_check {
    path     = "/"
    interval = 30
    timeout  = 5
    healthy_threshold = 5
    unhealthy_threshold = 2
  }
}


resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.load-balancer-labs.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.target-lb.arn
    type             = "forward"
  }
}



resource "aws_autoscaling_group" "autoscale" {
  name                      = "autoscale"
  max_size                  = 3
  min_size                  = 2
  desired_capacity          = 2
  health_check_type         = "ELB"
  launch_configuration      = aws_launch_configuration.config.id
  vpc_zone_identifier       = ["subnet-0048ff8647765d9e4","subnet-01633bd3e8d2842e9"]
  target_group_arns         = [aws_lb_target_group.target-lb.arn]
  health_check_grace_period = 300



}

resource "aws_autoscaling_attachment" "attachment" {
  autoscaling_group_name = aws_autoscaling_group.autoscale.name
  lb_target_group_arn   = aws_lb_target_group.target-lb.arn
}


resource "aws_launch_configuration" "config" {
  name_prefix = "config"
  image_id    = "ami-0747e613a2a1ff483"
  instance_type = "t2.micro"
  key_name  = "cheie"
  security_groups = ["sg-00b47d7fe27cc5bc8"]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install docker -y
              sudo usermod -aG docker ec2-user
              newgrp docker
              sudo systemctl start docker
              sudo yum install git -y
              docker network create devopslabs
              git clone https://github.com/teohodolean/api_labs.git
              cd api_labs/
              docker build -t backend_labs -f ./Dockerfile .
              docker run -d -p 8080:8080 --name backend_labs --network devopslabs backend_labs
              cd
              git clone https://github.com/teohodolean/nginx_final.git
              cd nginx_final/
              docker build -t frontend_labs -f ./Dockerfile .
              docker run -d -p 80:80 --name frontend_labs --network devopslabs frontend_labs

              EOF
}

resource "aws_autoscaling_policy" "scale-up" {
  name                   = "scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.autoscale.name

}

resource "aws_autoscaling_policy" "scale-down" {
  name                   = "scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.autoscale.name


}


resource "aws_cloudwatch_metric_alarm" "request_alarm_up" {
  alarm_name          = "request_alarm_up"
  alarm_description   = "Request increase"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 120
  statistic           = "Sum"
  threshold           = 25
  unit = "Count"

  dimensions    = {
    LoadBalancer = aws_lb.load-balancer-labs.arn_suffix
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale-up.arn]

}

resource "aws_cloudwatch_metric_alarm" "request_alarm_down" {
  alarm_name          = "request_alarm_down"
  alarm_description   = "Request decrease"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 120
  statistic           = "Sum"
  threshold           = 10
  unit                = "Count"
  dimensions    = {
    LoadBalancer = aws_lb.load-balancer-labs.arn_suffix
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale-down.arn]

}