Terraform code for creating a load balancer and an autoscaling group that will be connected to the load balancer. 
The autosclaing group is set to have 2 instances and a maximum of 3 instances, it will add another instance if there are more then 25 request per 2 minutes to the load balancer and it will lower the number of instances to 2 if there are less then 10 request on 2 consecutive perios of 2 minutes.
The created instances will be running a clock aplication.
